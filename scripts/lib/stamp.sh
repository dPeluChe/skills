# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (REPO_DIR, ...) come from install.sh
# ── stamp: per-repo stamps -- gitleaks baseline, FLOW import, preship config ──
# Sourced by scripts/install.sh (the entrypoint); never executed directly.

gitleaks_config_label() { # $1 = target repo; prints the label of the config the
  # gitleaks-staged hook will use (repo-local wins over central, mirroring the
  # precedence in hooks/lefthook-base.yml).
  if [[ -f "$1/.gitleaks.toml" ]]; then
    echo "repo-local .gitleaks.toml"
  else
    echo "central hooks/.gitleaks.toml"
  fi
}

run_gitleaks_baseline() { # $1 = target repo, $2 = team (0/1)
  local target="$1" team="${2:-0}" scan="git" n cfg
  local report="$target/.gitleaks-baseline.json"
  gitleaks git --help >/dev/null 2>&1 || scan="detect"
  # same precedence as the hook: repo-local .gitleaks.toml wins over central
  if [[ -f "$target/.gitleaks.toml" ]]; then
    cfg="$target/.gitleaks.toml"
  else
    cfg="$REPO_DIR/hooks/.gitleaks.toml"
  fi
  note "-> building gitleaks baseline (full history scan, one-time; config: $(gitleaks_config_label "$target"))..."
  # scan to a temp file: a re-wire merges into the reviewed baseline, never
  # overwrites it (field: re-running flowkit hooks wiped every classification)
  local fresh
  fresh="$(mktemp "${TMPDIR:-/tmp}/flowkit-baseline.XXXXXX")"
  ( cd "$target" && gitleaks "$scan" --config "$cfg" \
      --report-path "$fresh" --report-format json --redact \
      --exit-code 0 >/dev/null 2>&1 ) || true
  if [[ ! -s "$fresh" ]]; then
    rm -f "$fresh"
    bad "gitleaks baseline scan produced no report -- run it manually"
    return 0
  fi
  # rewrite, not count: dedup by (File, StartLine, RuleID), since history scans
  # repeat a leak per commit, and add classification/note fields that persist
  n="$(python3 - "$fresh" "$report" <<'PY' 2>/dev/null || { [[ -f "$report" ]] || cp "$fresh" "$report"; grep -c '"RuleID"' "$report"; } || echo "?"
import json, os, sys
fresh, p = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(fresh))
except Exception:
    raise SystemExit(1)
key = lambda x: (x.get("File"), x.get("StartLine"), x.get("RuleID"))
prior = {}
if os.path.exists(p):
    try:
        prior = {key(x): x for x in json.load(open(p))}
    except Exception:
        prior = {}
seen, out = set(), []
for x in data:
    k = key(x)
    if k in seen:
        continue
    seen.add(k)
    old = prior.get(k, {})
    x["classification"] = old.get("classification", "")   # real-rotate | public-by-design | false-positive
    x["note"] = old.get("note", "")
    out.append(x)
# trailing newline: without it a TRACKED baseline shows as modified on every
# re-wire even when the findings are identical, which is exactly the kind of
# no-op churn that trains people to ignore a dirty working tree
with open(p, "w") as fh:
    json.dump(out, fh, indent=2)
    fh.write("\n")
print(len(out))
PY
)"
  rm -f "$fresh"
  # these are HISTORICAL (full-history scan). Check whether the CURRENT working
  # tree is clean, so nobody "re-fixes" already-fixed/annotated code (field: 4
  # calls lost realising gitleaks detect --no-git finds nothing in the tree).
  local wt_clean=0
  ( cd "$target" && gitleaks detect --no-git --config "$cfg" --redact --exit-code 1 >/dev/null 2>&1 ) && wt_clean=1
  if [[ "$n" == "0" || "$n" == "?" ]]; then
    echo "  baseline: $n findings"
  else
    echo "  baseline: $n HISTORICAL finding(s) from the full-history scan -- grandfathered; NEW leaks still block."
    if [[ "$wt_clean" -eq 1 ]]; then
      echo "  the current working tree is CLEAN (already fixed/annotated) -- do NOT re-fix these; they are history."
    else
      echo "  NOTE: the current working tree ALSO has findings -- those are NOT grandfathered; fix or annotate them."
    fi
  fi
  if [[ "$n" != "0" && "$n" != "?" ]]; then
    echo "  +- file:line - rule ------------------------"
    python3 - "$report" "$target" 2>/dev/null <<'PY' || true
import json, os, re, sys

report, root = sys.argv[1], sys.argv[2]

def context(f):
    # (likely, real_line): "likely detector/fixture" when the finding sits in a
    # test/fixture/spec file or its line reads like a regex literal.
    path, ln = f.get("File", ""), f.get("StartLine") or 0
    line = ""
    try:
        with open(os.path.join(root, path), errors="replace") as fh:
            line = fh.read().splitlines()[ln - 1].strip()
    except Exception:
        line = ""
    likely = bool(re.search(r"test|fixture|spec", path.lower()))
    if line and re.search(r"\\b|\\d|\[0-9|\[A-Z|\{\d+,|\(\?i\)", line):
        likely = True
    return likely, line

seen = set()
for f in json.load(open(report)):
    key = (f.get("File"), f.get("StartLine"), f.get("RuleID"))
    if key in seen:
        continue
    seen.add(key)
    if len(seen) > 20:
        break
    where = f"{f.get('File', '?')}:{f.get('StartLine', '?')}"
    likely, line = context(f)
    tag = " [likely detector/fixture]" if likely else ""
    print(f"  | {where} - {f.get('RuleID', '?')}{tag}")
    if likely and line:
        print(f"  |   {line[:120]}")
PY
    echo "  +-------------------------------------------"
    echo "  These findings are grandfathered by the baseline; NEW leaks still block."
    echo "  [likely detector/fixture] entries show their REAL line (test/fixture file"
    echo "  or regex literal); the rest stay redacted."
    local files
    files="$(python3 - "$report" "$target" 2>/dev/null <<'PY' || echo "the baseline report"
import json, os, re, sys

report, root = sys.argv[1], sys.argv[2]

def likely(f):
    path, ln = f.get("File", ""), f.get("StartLine") or 0
    if re.search(r"test|fixture|spec", path.lower()):
        return True
    try:
        with open(os.path.join(root, path), errors="replace") as fh:
            line = fh.read().splitlines()[ln - 1]
    except Exception:
        return False
    return bool(re.search(r"\\b|\\d|\[0-9|\[A-Z|\{\d+,|\(\?i\)", line))

items = []
for f in json.load(open(report)):
    tag = ", likely detector/fixture" if likely(f) else ""
    items.append(f"{f.get('File', '?')}:{f.get('StartLine', '?')} "
                 f"({f.get('RuleID', '?')}{tag})")
extra = f" and {len(items) - 6} more" if len(items) > 6 else ""
print("; ".join(items[:6]) + extra)
PY
)"
    agent_action "Baseline grandfathered $n historical finding(s) in $files -- CLASSIFY each (do not assume dead): real secret to ROTATE at its provider / public-by-design (e.g. a Sentry DSN that ships in the bundle) / false positive (a var or key name that only looks secret-shaped). A clean baseline is not a rotation receipt. RECORD each verdict IN .gitleaks-baseline.json: set the entry's 'classification' (real-rotate | public-by-design | false-positive) and 'note' fields, so the next session inherits the review instead of re-doing it."
  else
    echo "  (0 findings -- clean history, baseline kept as an empty ledger)"
  fi
  # #6: if the repo already annotates with inline gitleaks:allow, the baseline is
  # for HISTORY (which cannot be annotated backward), NOT a decision to hide
  # current findings -- say so, so flowkit does not look like it overrode a choice.
  local n_allow
  # grep -c prints 0 AND exits 1 on no match: a `|| echo 0` would add a 2nd line
  n_allow="$(grep -rIl 'gitleaks:allow' "$target" 2>/dev/null \
    | grep -vcE '/\.git/|/node_modules/' 2>/dev/null || true)"
  n_allow="${n_allow%%$'\n'*}"      # first line only
  [[ "$n_allow" =~ ^[0-9]+$ ]] || n_allow=0
  if [[ "${n_allow:-0}" -gt 0 && "$n" != "0" && "$n" != "?" ]]; then
    echo "  this repo already uses inline 'gitleaks:allow' ($n_allow file(s)) -- the baseline covers HISTORY (can't be annotated backward), it does NOT override those inline decisions."
  fi
  if [[ "$team" == 1 ]]; then
    # team repos choose: share the ledger (commit) or keep it personal
    local share=""
    if [[ -t 0 ]]; then
      note ".gitleaks-baseline.json -- who should use this grandfathered-findings list?"
      note "  1) personal -- only this machine; kept out of git via .git/info/exclude  [default]"
      note "  2) team     -- commit it so every contributor grandfathers the same findings"
      read -r -p "choose [1/2, Enter = 1]: " share
    fi
    if [[ "$share" == 2 || "$share" == [sS]* ]]; then
      note "-> baseline SHARED: commit .gitleaks-baseline.json so the whole team grandfathers the same findings"
    else
      exclude_add "$target" ".gitleaks-baseline.json"
      note "-> baseline personal: .gitleaks-baseline.json added to .git/info/exclude (default; re-run with 's' to share)"
    fi
  elif [[ "$n" != "0" && "$n" != "?" ]]; then
    # #5 solo: the baseline is UNTRACKED. The pre-commit hook reads it locally,
    # but CI and teammates won't grandfather the same findings unless it's
    # committed -- silent divergence. Flag it (only when it carries findings).
    note "-> .gitleaks-baseline.json is UNTRACKED -- it grandfathers findings only on THIS machine. Commit it so CI + teammates inherit the same ledger (or add it to .git/info/exclude to keep it deliberately personal)."
  fi
}

ensure_flow_import() { # $1 = target repo, $2 = team (0/1): @import FLOW.
  # The import references a machine-local path (~/.agents/...), so on team
  # repos it goes to CLAUDE.local.md (personal, git-excluded) -- the committed
  # CLAUDE.md must stay portable for teammates without flowkit.
  local target="$1" team="${2:-0}" line='@~/.agents/skills/FLOW_CLAUDE.md' cmd
  ensure_flow_link
  if [[ "$team" == 1 ]]; then
    if grep -qF "$line" "$target/CLAUDE.md" 2>/dev/null; then
      note "-> committed CLAUDE.md already imports FLOW_CLAUDE.md -- consider moving that line to CLAUDE.local.md (machine-local path, not portable)"
      return 0
    fi
    cmd="$target/CLAUDE.local.md"
    [[ -f "$cmd" ]] || { printf '# CLAUDE.local.md -- personal, never committed\n' > "$cmd"; note "-> created CLAUDE.local.md"; }
    exclude_add "$target" "CLAUDE.local.md"
    if grep -qF "$line" "$cmd"; then
      note "-> CLAUDE.local.md already imports FLOW_CLAUDE.md"
    else
      printf '\n%s\n' "$line" >> "$cmd"
      note "-> added FLOW_CLAUDE.md import to CLAUDE.local.md (excluded via .git/info/exclude)"
    fi
    return 0
  fi
  cmd="$target/CLAUDE.md"
  [[ -f "$cmd" ]] || { printf '# CLAUDE.md\n' > "$cmd"; note "-> created CLAUDE.md"; }
  if grep -qF "$line" "$cmd"; then
    note "-> CLAUDE.md already imports FLOW_CLAUDE.md"
  else
    printf '\n%s\n' "$line" >> "$cmd"
    note "-> added FLOW_CLAUDE.md import to CLAUDE.md"
  fi
}

check_agent_docs_fences() { # $1 = target repo: agent instruction files must
  # reference paths, never embed code. Count ``` fences in CLAUDE.md/AGENTS.md,
  # excluding the canonical yaml fence of the "## preship config" section.
  # Detect + recommend only -- the agent running the install launches /doctos.
  local target="$1" file count=0 n detail=""
  for file in CLAUDE.md AGENTS.md; do
    [[ -f "$target/$file" ]] || continue
    n="$(awk '
      /^## (pre)?ship config$/ { ship = 1 }
      ship && /^## / && !/^## (pre)?ship config$/ { ship = 0 }
      /^```/ {
        if (open) { open = 0; next }
        open = 1
        if (!ship) n++
      }
      END { print n + 0 }
    ' "$target/$file")"
    count=$((count + n))
    [[ "$n" -gt 0 ]] && detail="${detail:+$detail, }$file: $n"
  done
  if [[ "$count" -gt 0 ]]; then
    note "-> $count embedded code blocks in CLAUDE.md/AGENTS.md -- agent instruction files should reference paths, not embed code; run /doctos to clean them up"
    if docs_is_published_site "$target"; then
      agent_action "Run /doctos on this repo: $count embedded code blocks in CLAUDE.md/AGENTS.md ($detail). Findings only -- docs/ is a published site, do NOT reorganize; fix in place."
    else
      agent_action "Run /doctos on this repo: $count embedded code blocks in CLAUDE.md/AGENTS.md ($detail)."
    fi
  fi
}

docs_is_published_site() { # $1 = target: docs/ serves a live website (GitHub
  # Pages & co.) -- reorganizing it breaks live URLs.
  local t="$1" f
  for f in CNAME index.html _config.yml; do
    [[ -e "$t/docs/$f" ]] && return 0
  done
  grep -qsE 'actions/(configure-pages|deploy-pages|jekyll)|github-pages|mkdocs gh-deploy' \
    "$t"/.github/workflows/*.yml "$t"/.github/workflows/*.yaml 2>/dev/null
}

STEWARD_MARK="stamped by flowkit"

ensure_steward_skill() { # $1 = target repo: instructions for Claude Code's /ship watch.
  # The watch pushes with git hooks off, so it is told to run the gates itself.
  # Local and excluded: it names a machine-local CLI, like the FLOW import.
  local target="$1" f="$1/.claude/skills/steward/SKILL.md"
  if [[ -f "$f" ]]; then
    grep -qF "$STEWARD_MARK" "$f" || note "-> .claude/skills/steward/SKILL.md exists (project-owned) -- left as is; make sure it runs the gates before each push"
    return 0
  fi
  mkdir -p "$(dirname "$f")"
  cat > "$f" <<EOF
---
name: steward
description: How to look after pull requests in this repo during a /ship or /steward watch ($STEWARD_MARK).
user-invocable: false
disable-model-invocation: true
---

# Watching pull requests in this repo

Git hooks do not run during a watch, so this repo's pre-commit secret scan and
pre-push lint are off for your commits. Before every push:

1. Run \`flowkit gate\` from the repo root. It scans the commits since the base
   branch for secrets and runs the lint and typecheck declared in the
   \`## preship config\` block of CLAUDE.md. Without \`flowkit\` on PATH, run
   those commands from that block yourself, plus
   \`gitleaks git --redact --log-opts="origin/<base>..HEAD"\`.
2. If it fails, fix the cause and rerun. Never push a red gate, never weaken a
   lint rule or add a blanket eslint-disable to make it pass.

Also:
- Never commit .env files or anything that looks like a credential.
- Regenerate lockfiles with the package manager, never edit them by hand.
- Fix what is mechanical; leave design-level review comments to the author.
EOF
  exclude_add "$target" ".claude/skills/steward/SKILL.md"
  note "-> stamped .claude/skills/steward/SKILL.md (the /ship watch runs flowkit gate before each push; excluded via .git/info/exclude)"
}
