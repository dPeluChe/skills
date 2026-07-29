#!/usr/bin/env bash
# Sync skills into the 2-hop chain used by this machine:
#   ~/.claude/skills/<name> -> ~/.agents/skills/<name> -> <repo>/skills/<name>
# (~/.agents/skills is the shared hub so every agent harness serves the same skills.)
#
# Usage:
#   ./scripts/install.sh              # sync ALL repo skills (create/fix missing links)
#   ./scripts/install.sh ship         # sync one skill
#   ./scripts/install.sh --check      # doctor mode: validate everything, change nothing (exit 0/1)
#   ./scripts/install.sh --prune      # sync + remove orphan links that point into this repo
#   ./scripts/install.sh --copy X     # legacy: copy instead of link (single hop, discouraged)
#   ./scripts/install.sh --repo <path> [--team] [--children-only|--include-parent]
#                                     # phase 2: wire centralized git hooks
#                                     # (lefthook remotes + gitleaks baseline +
#                                     # FLOW_CLAUDE.md import) into a target repo.
#                                     # If <path> is a WORKSPACE (a git repo whose
#                                     # 1st-level children are git repos), each child
#                                     # gets wired instead; the parent is skipped
#                                     # unless --include-parent (workspace roots
#                                     # carry their own no-commit locks).
#   ./scripts/install.sh --repo <path> --verify
#                                     # verify the EFFECTIVE hook state of <path>:
#                                     # config present + effective hooksPath
#                                     # invokes lefthook + gitleaks accessible +
#                                     # no orphan stubs -- exit 0/1
#   ./scripts/install.sh --unhook <path>
#                                     # clean removal from <path>: lefthook stubs
#                                     # (effective hooksPath + .git/hooks), OUR
#                                     # lefthook config files and OUR
#                                     # .git/info/exclude entries
#   ./scripts/install.sh --upgrade    # report lefthook/gitleaks versions vs minimums
#                                     # (+ brew outdated) and this clone vs
#                                     # origin/main — exit 0 fresh, 1 pending
#   ./scripts/install.sh --about      # orientation for agents landing cold:
#                                     # what flowkit is (static) + this repo's
#                                     # detected flow status (dynamic, if $PWD
#                                     # is a git repo). Always exits 0.
#   ./scripts/install.sh --harness    # wire the Claude Code harness hooks:
#                                     # symlink ~/.agents/hooks-harness -> hooks/harness
#                                     # + merge the 2 PreToolUse guards (git-guard,
#                                     # secret-guard) into ~/.claude/settings.json
#                                     # (idempotent; backup to settings.json.bak).
#                                     # --check also validates both once installed.
#
# Sync mode also links ~/bin/flowkit -> bin/flowkit (the CLI front-end that
# dispatches every subcommand back to this script); --check validates that link.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
BIN_DIR="${FLOWKIT_BIN_DIR:-$HOME/bin}"
HARNESS_LINK="${AGENTS_HOOKS_DIR:-$HOME/.agents/hooks-harness}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
MODE="sync"; COPY=0; PROBLEMS=0; TARGET_REPO=""; TEAM=0; INCLUDE_PARENT=0
VERIFY_ONLY=0; VERIFY_FAILED=0; LAST_VERIFY_RC=0

case "${1:-}" in
  --check)   MODE="check"; shift ;;
  --prune)   MODE="prune"; shift ;;
  --copy)    COPY=1; shift ;;
  --upgrade) MODE="upgrade"; shift ;;
  --harness) MODE="harness"; shift ;;
  --about)   MODE="about"; shift ;;
  --repo)
    MODE="repo"; shift
    TARGET_REPO="${1:?usage: install.sh --repo <path> [--team] [--children-only|--include-parent]}"; shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --team)           TEAM=1; shift ;;
        --children-only)  INCLUDE_PARENT=0; shift ;;  # default; kept explicit
        --include-parent) INCLUDE_PARENT=1; shift ;;
        --verify)         VERIFY_ONLY=1; shift ;;
        *) echo "x unknown --repo option: $1" >&2; exit 1 ;;
      esac
    done
    ;;
  --unhook)
    MODE="unhook"; shift
    TARGET_REPO="${1:?usage: install.sh --unhook <path>}"; shift
    ;;
esac

mkdir -p "$AGENTS_DIR" "$CLAUDE_DIR"

note() { echo "$@"; }
bad()  { echo "x $*"; PROBLEMS=$((PROBLEMS + 1)); }

flowkit_version() { # prints "flowkit <VERSION> (<short sha>)"
  local v sha
  v="$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo 0.0.0)"
  sha="$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf 'flowkit %s (%s)\n' "$v" "$sha"
}

# ── one skill: ensure (or verify) both hops ────────────────────────────────
sync_one() {
  local name="$1" src="$REPO_DIR/skills/$1"
  local hop1="$AGENTS_DIR/$name" hop2="$CLAUDE_DIR/$name"
  [[ -d "$src" && -f "$src/SKILL.md" ]] || { bad "unknown skill or missing SKILL.md: $name"; return 0; }

  if [[ "$COPY" == 1 ]]; then
    rm -rf "$hop2"; cp -R "$src" "$hop2"; note "-> copied  $name (single hop, legacy)"; return 0
  fi

  # hop 1: ~/.agents/skills/<name> -> absolute repo path
  if [[ -L "$hop1" && "$(readlink "$hop1")" == "$src" ]]; then
    :
  elif [[ -e "$hop1" && ! -L "$hop1" ]]; then
    bad "$hop1 exists and is not a symlink -- remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "$name: hop1 missing/wrong ($hop1)"; return 0; }
    rm -f "$hop1"; ln -s "$src" "$hop1"; note "-> hop1 linked  $name"
  fi

  # hop 2: ~/.claude/skills/<name> -> ../../.agents/skills/<name> (relative, matches existing style)
  local want2="../../.agents/skills/$name"
  if [[ -L "$hop2" && "$(readlink "$hop2")" == "$want2" ]]; then
    :
  elif [[ -e "$hop2" && ! -L "$hop2" ]]; then
    bad "$hop2 exists and is not a symlink -- remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "$name: hop2 missing/wrong ($hop2)"; return 0; }
    rm -f "$hop2"; ln -s "$want2" "$hop2"; note "-> hop2 linked  $name"
  fi

  # end-to-end: the chain must resolve to a readable SKILL.md
  if [[ ! -f "$hop2/SKILL.md" ]]; then
    bad "$name: chain does not resolve to SKILL.md"
  elif [[ "$MODE" == "check" ]]; then
    note "ok $name"
  fi
}

# ── orphans: dead links that were meant for this chain ─────────────────────
scan_orphans() {
  local dir="$1" link target raw
  for link in "$dir"/*; do
    [[ -L "$link" ]] || continue
    target="$(readlink -f "$link" 2>/dev/null || true)"
    if [[ -z "$target" || ! -e "$target" ]]; then
      raw="$(readlink "$link")"
      if [[ "$raw" == *"$REPO_DIR"* || "$raw" == *".agents/skills"* ]]; then
        if [[ "$MODE" == "prune" ]]; then
          rm -f "$link"; note "-> pruned orphan $link"
        else
          bad "orphan link: $link -> $raw"
        fi
      fi
    fi
  done
}

# ── FLOW_CLAUDE.md: served through the same ~/.agents hub as the skills ────
ensure_flow_link() {
  local src="$REPO_DIR/FLOW_CLAUDE.md" link="$AGENTS_DIR/FLOW_CLAUDE.md"
  [[ -f "$src" ]] || { bad "FLOW_CLAUDE.md missing from repo root"; return 0; }
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    :
  elif [[ -e "$link" && ! -L "$link" ]]; then
    bad "$link exists and is not a symlink -- remove it to adopt"
  else
    [[ "$MODE" == "check" ]] && { bad "FLOW_CLAUDE.md link missing ($link)"; return 0; }
    rm -f "$link"; ln -s "$src" "$link"; note "-> FLOW linked  FLOW_CLAUDE.md"
  fi
}

# ── flowkit CLI: global entry point served from ~/bin ──────────────────────
ensure_flowkit_link() {
  local src="$REPO_DIR/bin/flowkit" link="$BIN_DIR/flowkit"
  [[ -f "$src" ]] || { bad "bin/flowkit missing from repo"; return 0; }
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    :
  elif [[ -e "$link" && ! -L "$link" ]]; then
    bad "$link exists and is not a symlink -- remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "flowkit link missing/wrong ($link)"; return 0; }
    mkdir -p "$BIN_DIR"
    rm -f "$link"; ln -s "$src" "$link"; note "-> flowkit linked  $link"
  fi
  # Complete the job: append the export to the shell rc (idempotent,
  # marker-guarded). FLOWKIT_NO_RC=1 opts out and prints the line instead.
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
      local rc_file="$HOME/.zshrc" export_line
      [[ "${SHELL:-}" == *bash* ]] && rc_file="$HOME/.bashrc"
      if [[ "$BIN_DIR" == "$HOME/bin" ]]; then
        # shellcheck disable=SC2016  # the line is meant literally for the rc file
        export_line='export PATH="$HOME/bin:$PATH"'
      else
        export_line="export PATH=\"$BIN_DIR:\$PATH\""
      fi
      if [[ "${FLOWKIT_NO_RC:-}" == "1" ]]; then
        note "! $BIN_DIR is not in your PATH -- add this line to $rc_file:"
        note "  $export_line"
      elif grep -qF "# flowkit PATH" "$rc_file" 2>/dev/null; then
        note "! $BIN_DIR not in this shell's PATH yet -- restart the shell (rc already configured)"
      else
        printf '\n# flowkit PATH\n%s\n' "$export_line" >> "$rc_file"
        note "-> PATH export appended to $rc_file -- restart the shell (or: source $rc_file)"
      fi
      ;;
  esac
}

# ── phase 2: centralized git hooks into a target repo (--repo <path>) ──────
REMOTE_URL="https://github.com/dPeluChe/skills"
MIN_LEFTHOOK="1.10"
MIN_GITLEAKS="8.19"   # 'gitleaks git' needs it

die() { echo "x $*" >&2; exit 1; }

# Actionable follow-ups collected while wiring one repo; printed at the end of
# that repo's section as a copy-paste block for the human's agent.
AGENT_ACTIONS=""
agent_action() { AGENT_ACTIONS="${AGENT_ACTIONS}$*"$'\n'; }
print_agent_actions() {
  [[ -n "$AGENT_ACTIONS" ]] || return 0
  echo ""
  echo "---- copy below to your agent ----"
  printf '%s' "$AGENT_ACTIONS"
  echo "For context on this tooling, run: flowkit about"
  echo "---- end ----"
}

# ver_ge <have> <need> — numeric dotted-version compare
ver_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" == "$2" ]]
}

tool_version() { # $1 = tool; prints its dotted version (empty if unknown)
  "$1" version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1
}

check_tool_versions() {
  local v missing=0
  if command -v lefthook >/dev/null 2>&1; then
    v="$(tool_version lefthook)"
    ver_ge "${v:-0}" "$MIN_LEFTHOOK" || { echo "x lefthook >= $MIN_LEFTHOOK required (found ${v:-?})"; missing=1; }
  else
    echo "x lefthook not found -- install it: brew install lefthook"; missing=1
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    v="$(tool_version gitleaks)"
    ver_ge "${v:-0}" "$MIN_GITLEAKS" || { echo "x gitleaks >= $MIN_GITLEAKS required for 'gitleaks git' (found ${v:-?})"; missing=1; }
  else
    echo "x gitleaks not found -- install it: brew install gitleaks"; missing=1
  fi
  [[ "$missing" == 0 ]] || die "missing/outdated tools -- install them and re-run"
}

write_remotes_config() { # $1 = destination yml path
  cat > "$1" <<EOF
# Managed by dPeluChe/skills scripts/install.sh --repo.
# Central hooks live in that repo (hooks/lefthook-base.yml); lefthook
# refetches them at most once a day.
remotes:
  - git_url: $REMOTE_URL
    ref: main
    refetch_frequency: 24h
    configs:
      - hooks/lefthook-base.yml
EOF
  note "-> wrote $(basename "$1")"
}

ensure_global_gitignore() { # team mode: lefthook-local.yml must be globally ignored
  local gi
  gi="$(git config --global core.excludesFile 2>/dev/null || true)"
  gi="${gi/#\~/$HOME}"
  [[ -n "$gi" ]] || gi="$HOME/.config/git/ignore"
  if [[ -f "$gi" ]] && grep -qxF "lefthook-local.yml" "$gi"; then
    note "-> global gitignore already covers lefthook-local.yml ($gi)"
  else
    mkdir -p "$(dirname "$gi")"
    printf 'lefthook-local.yml\n' >> "$gi"
    [[ -n "$(git config --global core.excludesFile 2>/dev/null || true)" ]] \
      || git config --global core.excludesFile "$gi"
    note "-> added lefthook-local.yml to global gitignore ($gi)"
  fi
}

chain_husky() { # $1 = target repo; append lefthook to husky hooks, never replace
  local target="$1" hook file
  note "-> husky detected -- chaining lefthook after it (not replacing)"
  for hook in pre-commit pre-push; do
    file="$target/.husky/$hook"
    if [[ -f "$file" ]] && grep -q "lefthook run $hook" "$file"; then
      continue
    fi
    printf 'lefthook run %s "$@"\n' "$hook" >> "$file"
    chmod +x "$file"
    note "-> chained lefthook into .husky/$hook"
  done
  echo "  NOTE: hooks stay husky-managed; lefthook runs as the last step of each."
}

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
  ( cd "$target" && gitleaks "$scan" --config "$cfg" \
      --report-path "$report" --report-format json --redact \
      --exit-code 0 >/dev/null 2>&1 ) || true
  if [[ ! -f "$report" ]]; then
    bad "gitleaks baseline scan produced no report -- run it manually"
    return 0
  fi
  n="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$report" 2>/dev/null \
    || grep -c '"RuleID"' "$report" || echo "?")"
  echo "  baseline: $n findings -- review them once"
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

for f in json.load(open(report))[:20]:
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
    agent_action "Baseline grandfathered $n historical findings in $files -- confirm they are dead/test data."
  else
    echo "  (0 findings -- clean history, baseline kept as an empty ledger)"
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

ship_config_has_todos() { # $1 = CLAUDE.md path: TODOs left in the ship config block?
  awk '/^## ship config$/ { s = 1; next } s && /^## / { s = 0 } s' "$1" 2>/dev/null \
    | grep -q 'TODO'
}

ship_hooks_skip_reason() { # $1 = target repo, $2 = hook name; prints the reason
  # declared as `hooks_skip: <hook>: reason` inside the ship config yaml fence
  # of CLAUDE.md (same sed-parseable format as lint:/typecheck:) -- empty when
  # the hook is not consciously skipped.
  local block
  # shellcheck disable=SC2016  # backtick fences are literal, not expansions
  block="$(sed -n '/^## ship config$/,/^## /p' "$1/CLAUDE.md" 2>/dev/null \
    | sed -n '/^```yaml$/,/^```$/p' | sed '1d;$d')"
  printf '%s\n' "$block" \
    | sed -n "s/^hooks_skip:[[:space:]]*$2:[[:space:]]*//p" \
    | sed 's/[[:space:]]*#.*$//; s/^["'"'"']//; s/["'"'"']$//; s/[[:space:]]*$//' \
    | head -1
}

lefthook_jobs_count() { # $1 = target repo, $2 = hook; how many jobs/commands the
  # MERGED config (lefthook dump: local + remotes cache) resolves for that hook.
  # Prints 0 when the config is inert or unparseable -- that IS the finding.
  ( cd "$1" && lefthook dump -f json 2>/dev/null ) | python3 -c '
import json, sys
try:
    cfg = json.load(sys.stdin)
except Exception:
    print(0)
    raise SystemExit
hook = cfg.get(sys.argv[1]) or {}
print(len(hook.get("jobs") or []) + len(hook.get("commands") or {}))
' "$2" 2>/dev/null || echo 0
}

canary_secret_scan() { # $1 = target repo. EFFICACY probe, not wiring: stage a
  # synthetic AWS-style key in an ISOLATED temp index (GIT_INDEX_FILE) and run
  # the same gitleaks invocation the pre-commit job runs. The user's real index
  # is never touched; the temp index is removed. Returns 0 = canary flagged
  # (gate effective), 1 = canary passed unseen, 2 = probe could not run.
  # (Canary value assembled at runtime so no secret-shaped literal lives here.)
  local target="$1" gitdir tmpidx blob rc=1 out canary
  canary="$(printf 'AKIA%s' "2J94QXKZR7T3W8Y5")"
  git -C "$target" rev-parse HEAD >/dev/null 2>&1 || return 2
  gitdir="$(git -C "$target" rev-parse --absolute-git-dir)" || return 2
  tmpidx="$gitdir/flowkit-canary-index.$$"
  rm -f "$tmpidx"
  blob="$(printf 'canary_key = "%s"\n' "$canary" \
    | git -C "$target" hash-object -w --stdin)" || return 2
  ( cd "$target" \
    && GIT_INDEX_FILE="$tmpidx" git read-tree HEAD \
    && GIT_INDEX_FILE="$tmpidx" git update-index --add \
         --cacheinfo "100644,$blob,flowkit-canary-probe.txt" \
  ) >/dev/null 2>&1 || { rm -f "$tmpidx"; return 2; }
  # config precedence mirrors the hook: repo-local > remotes cache > this clone
  local cargs=(git --staged --redact --no-banner) cfg=""
  if [[ -f "$target/.gitleaks.toml" ]]; then
    cfg="$target/.gitleaks.toml"
  else
    cfg="$(cd "$target" && find "$(git rev-parse --git-common-dir)/info/lefthook-remotes" \
      -path '*/hooks/.gitleaks.toml' 2>/dev/null | head -1)"
    [[ -z "$cfg" && -f "$REPO_DIR/hooks/.gitleaks.toml" ]] && cfg="$REPO_DIR/hooks/.gitleaks.toml"
  fi
  [[ -n "$cfg" ]] && cargs+=(--config "$cfg")
  [[ -f "$target/.gitleaks-baseline.json" ]] \
    && cargs+=(--baseline-path "$target/.gitleaks-baseline.json")
  out="$( ( cd "$target" && GIT_INDEX_FILE="$tmpidx" gitleaks "${cargs[@]}" ) 2>&1 )" && rc=1 || rc=0
  # exit != 0 alone could be a config error -- require the explicit verdict line
  grep -q "leaks found" <<<"$out" || rc=1
  rm -f "$tmpidx"
  return "$rc"
}

detect_stack_name() { # $1 = target repo; prints cargo|npm|python|go|generic
  if   [[ -f "$1/Cargo.toml" ]];     then echo cargo
  elif [[ -f "$1/package.json" ]];   then echo npm
  elif [[ -f "$1/pyproject.toml" ]]; then echo python
  elif [[ -f "$1/go.mod" ]];         then echo go
  else echo generic; fi
}

stack_suggested_cmds() { # $1 = stack; one-line paste-ready suggestion (or empty)
  case "$1" in
    cargo)  echo "lint: cargo fmt --check && cargo clippy -- -D warnings; build: cargo build; test: cargo test" ;;
    npm)    echo "lint: npm run lint; typecheck: npx tsc --noEmit; build: npm run build; test: npm test" ;;
    python) echo "lint: ruff check .; test: pytest" ;;
    go)     echo "lint: go vet ./...; build: go build ./...; test: go test ./..." ;;
    *)      echo "" ;;
  esac
}

ci_grep_cmd() { # $1 = target, $2 = ERE; prints "cmd<TAB>workflow" of the first
  # single-line `run:` command in .github/workflows/ matching the pattern.
  local f cmd
  for f in "$1"/.github/workflows/*.yml "$1"/.github/workflows/*.yaml; do
    [[ -f "$f" ]] || continue
    cmd="$(sed -n 's/^[[:space:]-]*run:[[:space:]]*//p' "$f" \
      | grep -vE '^[|>]' | grep -E "$2" | head -1)"
    [[ -n "$cmd" ]] && { printf '%s\t%s\n' "$cmd" "$(basename "$f")"; return 0; }
  done
  return 1
}

ensure_ship_config_template() { # $1 = target repo: stamp the block if missing.
  # Values come from the repo's CI workflows when extractable (marked
  # "# from <workflow> -- verify"); fallback is stack-flavored TODO examples.
  local target="$1" cmd="$1/CLAUDE.md" stack suggest fill_action hit from
  stack="$(detect_stack_name "$target")"
  suggest="$(stack_suggested_cmds "$stack")"
  fill_action="Fill the TODOs in the '## ship config' block of CLAUDE.md (lint/build/test commands for this stack)."
  [[ -n "$suggest" ]] && fill_action="$fill_action Suggested ($stack): $suggest -- paste and verify."
  if grep -q '^## ship config' "$cmd" 2>/dev/null; then
    note "-> CLAUDE.md already has a '## ship config' block"
    ship_config_has_todos "$cmd" && agent_action "$fill_action"
    return 0
  fi
  [[ -f "$cmd" ]] || { printf '# CLAUDE.md\n' > "$cmd"; note "-> created CLAUDE.md"; }

  local lint_line type_line build_line test_line ci_used=0
  case "$stack" in
    cargo)
      lint_line='lint:            # TODO e.g. cargo fmt --check && cargo clippy -- -D warnings'
      type_line='typecheck:       # TODO usually covered by clippy/build'
      build_line='build:           # TODO e.g. cargo build'
      test_line='test:            # TODO e.g. cargo test'
      ;;
    npm)
      lint_line='lint:            # TODO e.g. npm run lint'
      type_line='typecheck:       # TODO e.g. npx tsc --noEmit'
      build_line='build:           # TODO e.g. npm run build'
      test_line='test:            # TODO e.g. npm test (omit if none)'
      ;;
    python)
      lint_line='lint:            # TODO e.g. ruff check .'
      type_line='typecheck:       # TODO e.g. mypy .'
      build_line='build:           # TODO omit if none'
      test_line='test:            # TODO e.g. pytest'
      ;;
    go)
      lint_line='lint:            # TODO e.g. go vet ./...'
      type_line='typecheck:       # TODO covered by go build'
      build_line='build:           # TODO e.g. go build ./...'
      test_line='test:            # TODO e.g. go test ./...'
      ;;
    *)
      lint_line='lint:            # TODO e.g. npm run lint'
      type_line='typecheck:       # TODO e.g. npx tsc --noEmit'
      build_line='build:           # TODO e.g. npm run build'
      test_line='test:            # TODO omit if none'
      ;;
  esac
  # better than guessing: real commands already exercised by CI
  if hit="$(ci_grep_cmd "$target" '(^|[[:space:]/-])(lint|eslint|ruff check|clippy|fmt --check|golangci-lint)')"; then
    from="${hit#*$'\t'}"; lint_line="lint: ${hit%%$'\t'*}   # from $from -- verify"; ci_used=1
  fi
  if hit="$(ci_grep_cmd "$target" '(tsc|typecheck|type-check|mypy|go vet)')"; then
    from="${hit#*$'\t'}"; type_line="typecheck: ${hit%%$'\t'*}   # from $from -- verify"; ci_used=1
  fi
  if hit="$(ci_grep_cmd "$target" '(^|[[:space:]])[[:alnum:]_ -]*build')"; then
    from="${hit#*$'\t'}"; build_line="build: ${hit%%$'\t'*}   # from $from -- verify"; ci_used=1
  fi
  if hit="$(ci_grep_cmd "$target" '(^|[[:space:]])(test|pytest|jest|vitest)')"; then
    from="${hit#*$'\t'}"; test_line="test: ${hit%%$'\t'*}   # from $from -- verify"; ci_used=1
  fi

  cat >> "$cmd" <<EOF

## ship config

\`\`\`yaml
$lint_line
$type_line
$build_line
$test_line
merge_policy: ask   # auto | ask
loc_limit: 500
simplify: 500       # run /simplify only if changed LOC > N (off = only on request)
\`\`\`
EOF
  if [[ "$ci_used" == 1 ]]; then
    note "-> stamped '## ship config' template in CLAUDE.md ($stack stack; commands pre-filled from CI workflows -- verify them)"
    agent_action "Verify the CI-derived commands in the '## ship config' block of CLAUDE.md (marked '# from <workflow> -- verify')."
    ship_config_has_todos "$cmd" && agent_action "$fill_action"
    return 0
  else
    note "-> stamped '## ship config' template in CLAUDE.md ($stack stack detected -- fill the TODOs)"
    agent_action "$fill_action"
  fi
}

check_agent_docs_fences() { # $1 = target repo: agent instruction files must
  # reference paths, never embed code. Count ``` fences in CLAUDE.md/AGENTS.md,
  # excluding the canonical yaml fence of the "## ship config" section.
  # Detect + recommend only — the agent running the install launches /doctos.
  local target="$1" file count=0 n detail=""
  for file in CLAUDE.md AGENTS.md; do
    [[ -f "$target/$file" ]] || continue
    n="$(awk '
      /^## ship config$/ { ship = 1 }
      ship && /^## / && !/^## ship config$/ { ship = 0 }
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

# Global core.hooksPath is NOT a blocker when it holds CHAIN wrappers — files
# that delegate to $(git rev-parse --git-dir)/hooks/<hook> when it exists, so
# locally installed lefthook hooks still run through the chain.
global_hookspath_status() { # prints: none | chained | broken:<missing hooks>
  local gp missing="" hook file
  gp="$(git config --global core.hooksPath 2>/dev/null || true)"
  [[ -n "$gp" ]] || { echo "none"; return 0; }
  gp="${gp/#\~/$HOME}"
  for hook in pre-commit pre-push; do
    file="$gp/$hook"
    if [[ ! -f "$file" ]] || ! grep -q 'git rev-parse --git-dir' "$file"; then
      missing="$missing $hook"
    fi
  done
  if [[ -z "$missing" ]]; then echo "chained"; else echo "broken:${missing# }"; fi
}

local_tracked_hookspath() { # $1 = target repo; prints the repo-relative LOCAL
  # core.hooksPath dir when it is TRACKED (versioned hooks like .githooks);
  # fails otherwise. Installing lefthook stubs there would modify tracked files.
  local target="$1" lp
  lp="$(git -C "$target" config --local core.hooksPath 2>/dev/null || true)"
  [[ -n "$lp" ]] || return 1
  lp="${lp/#\~/$HOME}"
  case "$lp" in
    "$target"/*) lp="${lp#"$target"/}" ;;
    /*) return 1 ;;   # absolute path outside the repo: nothing tracked to protect
  esac
  [[ -n "$(git -C "$target" ls-files -- "$lp" 2>/dev/null)" ]] || return 1
  printf '%s\n' "$lp"
}

effective_hooks_dir() { # $1 = target repo; ABSOLUTE dir git actually consults
  # for hooks: core.hooksPath (local wins over global) or .git/hooks.
  local target="$1" hp
  hp="$(git -C "$target" config core.hooksPath 2>/dev/null || true)"
  if [[ -z "$hp" ]]; then
    printf '%s/hooks\n' "$(git -C "$target" rev-parse --absolute-git-dir)"
    return 0
  fi
  hp="${hp/#\~/$HOME}"
  case "$hp" in
    /*) printf '%s\n' "$hp" ;;
    *)  printf '%s/%s\n' "$target" "$hp" ;;
  esac
}

exclude_add() { # $1 = target repo, $2 = exact line for .git/info/exclude
  local ex
  ex="$(git -C "$1" rev-parse --absolute-git-dir)/info/exclude"
  mkdir -p "$(dirname "$ex")"
  grep -qxF "$2" "$ex" 2>/dev/null || printf '%s\n' "$2" >> "$ex"
}

exclude_remove() { # $1 = target repo, $2 = exact line; 0 only if it was removed
  local ex tmp
  ex="$(git -C "$1" rev-parse --absolute-git-dir)/info/exclude"
  { [[ -f "$ex" ]] && grep -qxF "$2" "$ex"; } || return 1
  tmp="$(mktemp)"
  grep -vxF "$2" "$ex" > "$tmp" || true
  mv "$tmp" "$ex"
}

lefthook_cfg_file() { # $1 = target; prints the config file referencing our remote
  local target="$1" f
  for f in lefthook.yml lefthook-local.yml; do
    if [[ -f "$target/$f" ]] && grep -qF "$REMOTE_URL" "$target/$f"; then
      printf '%s\n' "$f"; return 0
    fi
  done
  return 1
}

hook_invokes_lefthook() { # $1 = target, $2 = hook name; does the hook git will
  # ACTUALLY run invoke lefthook (directly, or via a chain wrapper delegating to
  # a lefthook stub in .git/hooks)?
  local target="$1" hook="$2" ehp file gitdir
  ehp="$(effective_hooks_dir "$target")"
  file="$ehp/$hook"
  [[ -f "$file" ]] || return 1
  grep -q lefthook "$file" && return 0
  if grep -q 'git rev-parse --git-dir' "$file"; then
    gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
    [[ -f "$gitdir/hooks/$hook" ]] && grep -q lefthook "$gitdir/hooks/$hook" && return 0
  fi
  return 1
}

verify_repo_hooks() { # $1 = target repo. EFFECTIVE-state verification: config
  # present + the hooks git actually runs invoke lefthook + the merged config
  # resolves REAL jobs + gitleaks accessible (and which config it uses) + a
  # canary secret is actually flagged + no orphan stubs. A hook consciously
  # skipped via `hooks_skip: <hook>: reason` in the ship config block reports
  # ok-skipped instead of failing. Prints a report; returns 0 active / 1 not.
  local target="$1" rc=0 cfg="" ehp gitdir hook f stubs=0 resolvable=0
  local skip_reason jobs
  ehp="$(effective_hooks_dir "$target")"
  gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
  echo "-- verify: effective hook state ($target)"
  if cfg="$(lefthook_cfg_file "$target")"; then
    echo "ok config: $cfg references $REMOTE_URL"
  else
    echo "x config: no lefthook.yml/lefthook-local.yml referencing $REMOTE_URL"
    rc=1
  fi
  for hook in pre-commit pre-push commit-msg; do
    skip_reason="$(ship_hooks_skip_reason "$target" "$hook")"
    if [[ -n "$skip_reason" ]]; then
      echo "ok $hook (skipped: $skip_reason) -- conscious skip declared in ship config hooks_skip"
      continue
    fi
    if hook_invokes_lefthook "$target" "$hook"; then
      echo "ok $hook: effective hooksPath invokes lefthook"
    else
      echo "x $hook: hooks NOT active -- the hook git runs ($ehp/$hook) never invokes lefthook"
      rc=1
    fi
  done
  # wiring can be perfect and the gate still INERT: the merged config must
  # resolve real jobs (field case: only lefthook-local.yml present -> 0 jobs)
  if [[ -n "$cfg" ]] && command -v lefthook >/dev/null 2>&1 \
     && [[ -z "$(ship_hooks_skip_reason "$target" pre-commit)" ]]; then
    jobs="$(lefthook_jobs_count "$target" pre-commit)"
    if [[ "$jobs" -gt 0 ]]; then
      echo "ok jobs: pre-commit resolves $jobs job(s) (lefthook dump)"
    else
      if [[ -f "$target/lefthook-local.yml" && ! -f "$target/lefthook.yml" ]]; then
        echo "x jobs: pre-commit resolves 0 jobs -- only personal overlay present; without a base config lefthook merges no jobs (lefthook-local.yml alone is inert: write lefthook.yml with the remotes block, or re-run: flowkit hooks)"
      else
        echo "x jobs: pre-commit resolves 0 jobs ('lefthook dump') -- the gate is inert (empty config or remotes cache never fetched; run: flowkit upgrade inside this repo to refresh it)"
      fi
      rc=1
    fi
  fi
  if command -v lefthook >/dev/null 2>&1; then
    echo "ok lefthook: $(tool_version lefthook) accessible"
  else
    echo "x lefthook: not found (brew install lefthook)"
    rc=1
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    echo "ok gitleaks: $(tool_version gitleaks) accessible"
    if [[ -f "$target/.gitleaks.toml" ]]; then
      echo "ok gitleaks config: repo-local .gitleaks.toml (replaces the central rules -- keep '[extend] useDefault = true' inside it)"
    else
      echo "ok gitleaks config: central (hooks/.gitleaks.toml via lefthook remotes)"
    fi
    # canary: prove EFFICACY, not just wiring -- a synthetic secret staged in
    # an isolated temp index must be flagged by the exact scan the hook runs
    if [[ -n "$(ship_hooks_skip_reason "$target" pre-commit)" ]]; then
      echo "- canary: skipped (pre-commit consciously skipped via hooks_skip)"
    else
      canary_secret_scan "$target"
      case "$?" in
        0) echo "ok canary: synthetic secret staged in an isolated index IS flagged ($(gitleaks_config_label "$target"))" ;;
        1) echo "x canary: a synthetic AWS-style key passed the scan UNSEEN ($(gitleaks_config_label "$target")) -- the secret gate is ineffective; a repo-local .gitleaks.toml must extend the defaults ([extend] useDefault = true)"
           rc=1 ;;
        *) echo "- canary: probe could not run (no HEAD yet?) -- efficacy unproven, wiring checks above still hold" ;;
      esac
    fi
  else
    echo "x gitleaks: not found -- secret scan will be skipped (brew install gitleaks)"
    rc=1
  fi
  # orphan stubs: lefthook hook files present while no config resolves --
  # lefthook errors out on every push instead of running jobs
  for f in "$ehp"/* "$gitdir"/hooks/*; do
    [[ -f "$f" ]] && grep -q lefthook "$f" 2>/dev/null && { stubs=1; break; }
  done
  if [[ "$stubs" == 1 ]]; then
    if [[ -n "$cfg" ]] && command -v lefthook >/dev/null 2>&1 \
       && ( cd "$target" && lefthook dump >/dev/null 2>&1 ); then
      resolvable=1
    fi
    if [[ "$resolvable" == 0 ]]; then
      echo "x orphan lefthook stubs -- they will break pushes; run: flowkit unhook"
      rc=1
    fi
  fi
  if [[ "$rc" -eq 0 ]]; then
    echo "-- verify: PASS (hooks active end-to-end)"
  else
    echo "-- verify: FAIL -- hooks are NOT fully active in this repo"
  fi
  return "$rc"
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

verify_tracked_hooks_dir_clean() { # $1 = target repo, $2 = tracked hooks dir
  # (repo-relative). Undo anything lefthook wrote into it: restore modified
  # tracked files, delete untracked stubs -- only files that mention lefthook.
  local target="$1" dir="$2" dirty line st path
  dirty="$(git -C "$target" status --porcelain -- "$dir" 2>/dev/null || true)"
  if [[ -z "$dirty" ]]; then
    note "-> tracked hooks dir $dir verified clean (git status)"
    return 0
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    st="${line:0:2}"; path="${line:3}"
    grep -q lefthook "$target/$path" 2>/dev/null || continue
    if [[ "$st" == "??" ]]; then
      rm -f "$target/$path"; note "-> removed lefthook stub $path from tracked hooks dir"
    else
      git -C "$target" checkout -- "$path" 2>/dev/null \
        && note "-> restored $path (lefthook had overwritten it)"
    fi
  done <<<"$dirty"
  dirty="$(git -C "$target" status --porcelain -- "$dir" 2>/dev/null || true)"
  if [[ -z "$dirty" ]]; then
    note "-> tracked hooks dir $dir verified clean (git status)"
  else
    bad "tracked hooks dir $dir still has changes after install -- review: git -C $target status -- $dir"
  fi
}

cleanup_team_autocreated_yml() { # $1 = target repo, $2 = lefthook.yml existed
  # before install (0/1). 'lefthook install' auto-creates lefthook.yml when the
  # repo has none ("Config not found, creating..."); in team mode that leaves a
  # committable file this tool never meant to add. Remove it when it is
  # untracked AND lefthook-made; a tracked one belongs to the project.
  local target="$1" existed="$2" yml="$1/lefthook.yml"
  [[ -f "$yml" ]] || return 0
  if git -C "$target" ls-files --error-unmatch lefthook.yml >/dev/null 2>&1; then
    note "-> project tracks its own lefthook.yml -- kept untouched; lefthook-local.yml extends it"
  elif [[ "$existed" == 0 ]] || grep -qi 'example usage' "$yml"; then
    rm -f "$yml"
    note "-> removed lefthook.yml auto-created by 'lefthook install' (team mode: config lives in lefthook-local.yml)"
  fi
}

wire_repo_hooks() { # $1 = target repo (absolute); full wiring of ONE repo, no exit
  local target="$1" team="$TEAM" cfg_file answer hookspath gitdir local_hp had_lefthook_yml=0
  AGENT_ACTIONS=""
  [[ -f "$target/lefthook.yml" ]] && had_lefthook_yml=1

  # solo vs team: flag wins; otherwise ask (non-interactive defaults to solo)
  if [[ "$team" == 0 && -t 0 ]]; then
    read -r -p "Does $(basename "$target") have a team (shared lefthook.yml)? [y/N] " answer
    [[ "$answer" == [yY]* ]] && team=1
  fi

  if [[ "$team" == 1 ]]; then
    cfg_file="$target/lefthook-local.yml"
    ensure_global_gitignore
  else
    cfg_file="$target/lefthook.yml"
  fi
  if [[ -f "$cfg_file" ]] && ! grep -qF "$REMOTE_URL" "$cfg_file"; then
    bad "$(basename "$cfg_file") exists and does not reference $REMOTE_URL -- merge this snippet manually:"
    echo "  remotes:"
    echo "    - git_url: $REMOTE_URL"
    echo "      ref: main"
    echo "      refetch_frequency: 24h"
    echo "      configs: [hooks/lefthook-base.yml]"
  else
    write_remotes_config "$cfg_file"
  fi

  hookspath="$(global_hookspath_status)"
  if [[ -d "$target/.husky" ]]; then
    chain_husky "$target"
  elif local_hp="$(local_tracked_hookspath "$target")"; then
    # repo-LOCAL core.hooksPath pointing at a TRACKED dir (versioned hooks):
    # never install stubs there -- lefthook would rewrite tracked files. Same
    # scoped override as the global-chained case: stubs go to .git/hooks.
    gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
    if ( cd "$target" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
        GIT_CONFIG_VALUE_0="$gitdir/hooks" lefthook install --force ); then
      note "-> local core.hooksPath ($local_hp) is tracked -- lefthook stubs installed in .git/hooks; the project's hooks in $local_hp stay intact"
    else
      bad "lefthook install --force failed -- see its message above; fix and re-run"
    fi
    verify_tracked_hooks_dir_clean "$target" "$local_hp"
    # honesty check: with a LOCAL core.hooksPath git only ever runs $local_hp --
    # the stubs in .git/hooks are dead code unless the project's hooks delegate
    local delegated=1 h
    for h in pre-commit pre-push; do
      hook_invokes_lefthook "$target" "$h" || delegated=0
    done
    if [[ "$delegated" == 0 ]]; then
      note "!! hooks NOT active in this repo: git uses the tracked hooksPath ($local_hp), so the lefthook stubs in .git/hooks are never invoked"
      note "   two ways out:"
      note "   1) PR a delegation line into the project's own hooks -- append to $local_hp/pre-commit and $local_hp/pre-push (matching hook name):"
      note '        command -v lefthook >/dev/null 2>&1 && lefthook run pre-commit "$@"'
      note "   2) skip consciously: this repo keeps only its own hooks (re-check any time with: flowkit hooks --verify)"
      agent_action "Hooks NOT active in this repo (tracked core.hooksPath $local_hp). Either PR the lefthook delegation line into $local_hp/pre-commit and $local_hp/pre-push, or record the conscious skip."
    fi
  elif [[ "$hookspath" == broken:* ]]; then
    bad "global core.hooksPath set but chain wrapper(s) missing for: ${hookspath#broken:} -- each wrapper must delegate to \$(git rev-parse --git-dir)/hooks/<hook>; add them and re-run"
  elif [[ "$hookspath" == "chained" ]]; then
    # lefthook installs into `git rev-parse --git-path hooks`, which honors the
    # GLOBAL core.hooksPath — a plain --force would clobber the chain wrappers.
    # Scope-override hooksPath to the local hooks dir so stubs land in
    # .git/hooks/, exactly where the wrappers delegate.
    gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
    if ( cd "$target" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
        GIT_CONFIG_VALUE_0="$gitdir/hooks" lefthook install --force ); then
      note "-> global hooksPath with chain wrappers: OK -- lefthook stubs in .git/hooks (invoked via the chain)"
    else
      bad "lefthook install --force failed -- see its message above; fix and re-run"
    fi
  elif ( cd "$target" && lefthook install ); then
    note "-> lefthook install done"
  else
    bad "lefthook install failed -- see its message above (e.g. a custom core.hooksPath); fix and re-run"
  fi

  [[ "$team" == 1 ]] && cleanup_team_autocreated_yml "$target" "$had_lefthook_yml"

  run_gitleaks_baseline "$target" "$team"
  # never stamped automatically: a generic fixed-length regex is a false-positive
  # decision only the project can make -- the agent block carries the nudge
  if [[ ! -f "$target/.gitleaks.toml" ]]; then
    agent_action "Project-specific secret formats (e.g. fixed-length CSPRNG tokens) are invisible to the central rules -- add a repo-local .gitleaks.toml (extend useDefault) with a rule for YOUR token format."
  fi
  ensure_flow_import "$target" "$team"
  ensure_ship_config_template "$target"
  check_agent_docs_fences "$target"
  if docs_is_published_site "$target"; then
    # agent guidance travels attached to the fence finding itself (see
    # check_agent_docs_fences) -- a second standalone line duplicated it
    note "-> docs/ looks like a PUBLISHED SITE (CNAME/index.html/_config.yml or a Pages workflow)"
  fi
  # the install ENDS with the effective-state verification -- no false "wired ok"
  LAST_VERIFY_RC=0
  verify_repo_hooks "$target" || LAST_VERIFY_RC=1
  if [[ "$LAST_VERIFY_RC" -ne 0 ]]; then
    VERIFY_FAILED=$((VERIFY_FAILED + 1))
    agent_action "flowkit hooks --verify FAILED for this repo -- hooks are not fully active; see the verify lines above (delegation PR or conscious skip)."
  fi
  print_agent_actions
}

list_child_repos() { # $1 = candidate workspace root; prints 1st-level dirs that are git repos
  local d
  for d in "$1"/*/; do
    [[ -e "${d}.git" ]] || continue
    git -C "${d%/}" rev-parse --git-dir >/dev/null 2>&1 && printf '%s\n' "${d%/}"
  done
}

install_repo() {
  local target child before name
  target="$(cd "$TARGET_REPO" 2>/dev/null && pwd)" || die "not a directory: $TARGET_REPO"
  git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $target"

  # --verify: effective-state check only, no wiring, exit 0/1
  if [[ "$VERIFY_ONLY" == 1 ]]; then
    if verify_repo_hooks "$target"; then exit 0; else exit 1; fi
  fi

  check_tool_versions

  local children=()
  while IFS= read -r child; do children+=("$child"); done < <(list_child_repos "$target")

  # plain repo (no git children) → wire it directly, previous behavior
  if [[ "${#children[@]}" -eq 0 ]]; then
    wire_repo_hooks "$target"
    if [[ "$PROBLEMS" -gt 0 ]]; then
      echo "-- $PROBLEMS problem(s) found"
      exit 1
    fi
    if [[ "$VERIFY_FAILED" -gt 0 ]]; then
      echo "-- wiring finished, but hooks are NOT fully active in $target -- see the verify report above."
    else
      echo "-- hooks wired into $target. First commit exercises them."
    fi
    exit 0
  fi

  # WORKSPACE: a git repo whose 1st-level children are git repos themselves.
  # Each child gets wired; the parent is skipped by default (workspace roots
  # carry their own no-commit locks) unless --include-parent.
  note "-> workspace detected: ${#children[@]} child repo(s) under $target"
  local targets=() results=()
  if [[ "$INCLUDE_PARENT" == 1 ]]; then
    targets+=("$target")
  else
    note "-> parent skipped (use --include-parent to wire it too)"
  fi
  targets+=("${children[@]}")

  for child in "${targets[@]}"; do
    name="$(basename "$child")"
    [[ "$child" == "$target" ]] && name="$name (parent)"
    before="$PROBLEMS"
    echo ""
    note "-- wiring $name"
    wire_repo_hooks "$child"
    if [[ "$PROBLEMS" -gt "$before" ]]; then
      results+=("$name|$((PROBLEMS - before)) problem(s)")
    elif [[ "$LAST_VERIFY_RC" -ne 0 ]]; then
      results+=("$name|hooks NOT active (verify failed)")
    else
      results+=("$name|ok")
    fi
  done

  echo ""
  echo "-- workspace report ($target)"
  printf '  %-32s %s\n' "repo" "result"
  printf '  %-32s %s\n' "----" "------"
  for child in "${results[@]}"; do
    printf '  %-32s %s\n' "${child%%|*}" "${child##*|}"
  done
  if [[ "$PROBLEMS" -gt 0 ]]; then
    echo "-- $PROBLEMS problem(s) found"
    exit 1
  fi
  if [[ "$VERIFY_FAILED" -gt 0 ]]; then
    echo "-- wired ${#targets[@]} repo(s); hooks NOT fully active in $VERIFY_FAILED of them -- see the verify lines above."
  else
    echo "-- hooks wired into ${#targets[@]} repo(s). First commit in each exercises them."
  fi
  exit 0
}

if [[ "$MODE" == "repo" ]]; then install_repo; fi

# ── unhook (--unhook <path>): clean removal of OUR wiring from one repo ─────
run_unhook() {
  local target gitdir ehp d f rel base line
  local removed=()
  target="$(cd "$TARGET_REPO" 2>/dev/null && pwd)" || die "not a directory: $TARGET_REPO"
  git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $target"
  gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
  ehp="$(effective_hooks_dir "$target")"

  # lefthook stubs: effective hooksPath + .git/hooks. Tracked files that
  # mention lefthook (a project-owned delegation) are respected with a notice.
  local dirs=("$gitdir/hooks")
  if [[ "$ehp" != "$gitdir/hooks" ]]; then
    case "$ehp" in
      "$target"/*|"$gitdir"/*) dirs+=("$ehp") ;;
      *) note "! effective hooksPath ($ehp) lives outside this repo (shared by others) -- not touched" ;;
    esac
  fi
  for d in "${dirs[@]}"; do
    for f in "$d"/*; do
      [[ -f "$f" ]] || continue
      grep -q lefthook "$f" 2>/dev/null || continue
      case "$f" in
        "$gitdir"/*) ;;
        "$target"/*)
          rel="${f#"$target"/}"
          if git -C "$target" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
            note "! $rel is TRACKED and mentions lefthook -- left in place (remove the delegation line via PR if unwanted)"
            continue
          fi
          ;;
      esac
      rm -f "$f"
      removed+=("lefthook stub|$f")
    done
  done

  # OUR config files: only the ones referencing our remote AND untracked.
  for base in lefthook.yml lefthook-local.yml; do
    f="$target/$base"
    [[ -f "$f" ]] || continue
    if git -C "$target" ls-files --error-unmatch "$base" >/dev/null 2>&1; then
      note "! $base is tracked (project-owned) -- left in place"
    elif grep -qF "$REMOTE_URL" "$f"; then
      rm -f "$f"
      removed+=("our config|$f")
    else
      note "! $base does not reference $REMOTE_URL (not ours) -- left in place"
    fi
  done

  # OUR .git/info/exclude entries (written by --team wiring).
  for line in "CLAUDE.local.md" ".gitleaks-baseline.json"; do
    if exclude_remove "$target" "$line"; then
      removed+=("exclude entry|$line (.git/info/exclude)")
    fi
  done

  echo ""
  echo "-- unhook report ($target)"
  if [[ "${#removed[@]}" -eq 0 ]]; then
    echo "  nothing to remove -- repo was not wired (or already clean)"
  else
    printf '  %-16s %s\n' "removed" "what"
    printf '  %-16s %s\n' "-------" "----"
    for f in "${removed[@]}"; do
      printf '  %-16s %s\n' "${f%%|*}" "${f##*|}"
    done
  fi
  exit 0
}

if [[ "$MODE" == "unhook" ]]; then run_unhook; fi

# -- about (--about): orientation for agents landing cold on a repo -----------
run_about() {
  echo "$(flowkit_version) -- manager for the skills + hooks + flow layer (github.com/dPeluChe/skills)"
  cat <<'EOF'

Four layers keep agent-driven work consistent and safe:
  1. harness guards    Claude Code PreToolUse hooks (git-guard, secret-guard)
  2. git hooks         centralized lefthook config fetched from this repo
  3. ship skill gates  lint/build/test read from '## ship config' in CLAUDE.md
  4. CI backstop       the same checks re-run server-side

Each repo's commands live in the '## ship config' block of its CLAUDE.md.
EOF
  git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0

  local root name hooks_mode="none" baseline="none" ship="absent" flow="no"
  local guards="not installed" n ehp gitdir f orphan=0
  root="$(git rev-parse --show-toplevel)"
  name="$(basename "$root")"
  if git -C "$root" ls-files --error-unmatch lefthook.yml >/dev/null 2>&1; then
    hooks_mode="lefthook.yml (committed)"
  elif [[ -f "$root/lefthook-local.yml" ]]; then
    hooks_mode="lefthook-local.yml (personal)"
  elif [[ -f "$root/lefthook.yml" ]]; then
    hooks_mode="lefthook.yml (untracked)"
  fi
  if [[ -f "$root/.gitleaks-baseline.json" ]]; then
    n="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' \
      "$root/.gitleaks-baseline.json" 2>/dev/null || echo "?")"
    baseline="present, $n findings grandfathered"
  fi
  if grep -q '^## ship config' "$root/CLAUDE.md" 2>/dev/null; then
    if ship_config_has_todos "$root/CLAUDE.md"; then
      ship="present (TODOs pending)"
    else
      ship="present"
    fi
  fi
  grep -qF '@~/.agents/skills/FLOW_CLAUDE.md' "$root/CLAUDE.md" 2>/dev/null && flow="yes"
  if grep -qF 'hooks-harness/git-guard.sh' "$CLAUDE_SETTINGS" 2>/dev/null \
     && grep -qF 'hooks-harness/secret-guard.sh' "$CLAUDE_SETTINGS" 2>/dev/null; then
    guards="installed"
  fi
  # orphan stubs: lefthook hook files present with no config at all --
  # every push errors out; unhook is the way out (same advice as --verify)
  if [[ ! -f "$root/lefthook.yml" && ! -f "$root/lefthook-local.yml" ]]; then
    ehp="$(effective_hooks_dir "$root")"
    gitdir="$(git -C "$root" rev-parse --absolute-git-dir)"
    for f in "$ehp"/* "$gitdir"/hooks/*; do
      [[ -f "$f" ]] && grep -q lefthook "$f" 2>/dev/null && { orphan=1; break; }
    done
  fi
  echo ""
  echo "This repo ($name):"
  echo "  hooks mode:      $hooks_mode"
  echo "  baseline:        $baseline"
  echo "  ship config:     $ship"
  echo "  FLOW import:     $flow"
  echo "  harness guards:  $guards"
  if [[ "$orphan" == 1 ]]; then
    echo "  orphan stubs:    lefthook stubs with NO config -- pushes will fail; run: flowkit unhook"
  fi
  exit 0
}

if [[ "$MODE" == "about" ]]; then run_about; fi

# ── Claude Code harness hooks (--harness): PreToolUse guards ───────────────
# git-guard.sh (matcher Bash) + secret-guard.sh (matcher Edit|Write) served
# through ~/.agents/hooks-harness and registered in ~/.claude/settings.json.

ensure_harness_link() {
  local src="$REPO_DIR/hooks/harness" link="$HARNESS_LINK"
  [[ -d "$src" ]] || { bad "hooks/harness missing from repo"; return 0; }
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    [[ "$MODE" == "check" ]] || note "-> harness link ok  $link"
  elif [[ -e "$link" && ! -L "$link" ]]; then
    bad "$link exists and is not a symlink -- remove it to adopt"
  else
    [[ "$MODE" == "check" ]] && { bad "harness link missing/wrong ($link)"; return 0; }
    mkdir -p "$(dirname "$link")"
    rm -f "$link"; ln -s "$src" "$link"; note "-> harness linked  $link"
  fi
}

merge_harness_settings() { # merge (or, in check mode, audit) the 2 guard entries
  # in $CLAUDE_SETTINGS. Prints ADDED/PRESENT/MISSING lines; everything else in
  # the JSON is preserved verbatim. Backup to settings.json.bak before writing.
  python3 - "$CLAUDE_SETTINGS" "$MODE" <<'PY'
import json, os, shutil, sys

path, mode = sys.argv[1], sys.argv[2]
wanted = [
    ("Bash", "$HOME/.agents/hooks-harness/git-guard.sh"),
    ("Edit|Write", "$HOME/.agents/hooks-harness/secret-guard.sh"),
]

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except ValueError:
        print(f"MALFORMED {path}")
        sys.exit(3)

pre = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
added, present = [], []
for matcher, cmd in wanted:
    entry = next((e for e in pre if e.get("matcher") == matcher), None)
    if entry is not None and any(
        h.get("command") == cmd for h in entry.get("hooks", [])
    ):
        present.append(f"{matcher} -> {cmd}")
        continue
    if mode != "check":
        if entry is None:
            pre.append({"matcher": matcher,
                        "hooks": [{"type": "command", "command": cmd}]})
        else:
            entry.setdefault("hooks", []).append(
                {"type": "command", "command": cmd})
    added.append(f"{matcher} -> {cmd}")

if mode != "check" and added:
    if os.path.exists(path):
        shutil.copyfile(path, path + ".bak")
    else:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

for line in present:
    print("PRESENT " + line)
for line in added:
    print(("MISSING " if mode == "check" else "ADDED ") + line)
PY
}

install_harness() {
  ensure_harness_link
  local out rc=0
  out="$(merge_harness_settings)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    bad "settings merge failed: ${out:-python3 error} -- fix $CLAUDE_SETTINGS and re-run"
  else
    local line
    while IFS= read -r line; do
      case "$line" in
        ADDED\ *)   note "-> settings: added        ${line#ADDED }" ;;
        PRESENT\ *) note "-> settings: already there ${line#PRESENT }" ;;
      esac
    done <<<"$out"
  fi
  if [[ "$PROBLEMS" -gt 0 ]]; then
    echo "-- $PROBLEMS problem(s) found"
    exit 1
  fi
  echo "-- harness hooks wired ($CLAUDE_SETTINGS). New Claude Code sessions pick them up."
  exit 0
}

check_harness() { # --check: validate link + settings entries once installed;
  # a machine that never ran --harness stays green (opt-in feature).
  local src="$REPO_DIR/hooks/harness" link="$HARNESS_LINK" out line rc=0
  out="$(merge_harness_settings)" || rc=$?
  [[ "$rc" -eq 0 ]] || { bad "harness: could not read $CLAUDE_SETTINGS (${out:-python3 error})"; return 0; }
  local link_ok=0
  [[ -L "$link" && "$(readlink "$link")" == "$src" ]] && link_ok=1
  if [[ "$link_ok" -eq 0 && ! -e "$link" ]] && ! grep -q '^PRESENT' <<<"$out"; then
    note "- harness hooks not installed (optional -- run: make harness)"
    return 0
  fi
  [[ "$link_ok" -eq 1 ]] || bad "harness link missing/wrong ($link)"
  if grep -q '^MISSING' <<<"$out"; then
    while IFS= read -r line; do
      [[ "$line" == MISSING\ * ]] && bad "harness settings entry missing: ${line#MISSING }"
    done <<<"$out"
  elif [[ "$link_ok" -eq 1 ]]; then
    note "ok harness hooks (link + 2 settings entries)"
  fi
}

if [[ "$MODE" == "harness" ]]; then install_harness; fi

# ── upgrade: versions vs minimums + this clone vs origin/main (--upgrade) ──
UPGRADE_PENDING=0

report_tool_upgrade() { # $1 = tool, $2 = required minimum; $BREW_OUTDATED may list it
  local name="$1" min="$2" cur
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "x $name: not installed - min $min -- brew install $name"
    UPGRADE_PENDING=1
    return 0
  fi
  cur="$(tool_version "$name")"
  if ! ver_ge "${cur:-0}" "$min"; then
    echo "x $name: ${cur:-?} - min $min - BELOW minimum -- brew upgrade $name"
    UPGRADE_PENDING=1
  elif [[ -n "$BREW_OUTDATED" ]] && grep -qxF "$name" <<<"$BREW_OUTDATED"; then
    echo "! $name: $cur - min $min ok - newer in brew -- brew upgrade $name"
    UPGRADE_PENDING=1
  else
    echo "ok $name: $cur - min $min - up to date"
  fi
}

run_upgrade() {
  BREW_OUTDATED=""
  if command -v brew >/dev/null 2>&1; then
    BREW_OUTDATED="$(brew outdated --quiet 2>/dev/null || true)"
  fi
  report_tool_upgrade lefthook "$MIN_LEFTHOOK"
  report_tool_upgrade gitleaks "$MIN_GITLEAKS"

  # standing inside a WIRED repo: refresh that repo's lefthook remotes cache so
  # a just-merged hooks change lands now instead of after the 24h refetch window
  local cwd_root="" cwd_gitdir
  cwd_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$cwd_root" && "$cwd_root" != "$REPO_DIR" ]] \
     && command -v lefthook >/dev/null 2>&1 \
     && lefthook_cfg_file "$cwd_root" >/dev/null; then
    cwd_gitdir="$(git -C "$cwd_root" rev-parse --absolute-git-dir)"
    if ( cd "$cwd_root" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
        GIT_CONFIG_VALUE_0="$cwd_gitdir/hooks" lefthook install --force >/dev/null 2>&1 ); then
      echo "ok $(basename "$cwd_root"): remotes refreshed (lefthook install re-synced this repo's cache)"
    else
      echo "x $(basename "$cwd_root"): lefthook install failed -- remotes NOT refreshed"
      UPGRADE_PENDING=1
    fi
  fi

  # this skills clone vs its public remote — report only, never pull
  local behind
  if git -C "$REPO_DIR" fetch --quiet origin 2>/dev/null; then
    behind="$(git -C "$REPO_DIR" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")"
    if [[ "$behind" == "0" ]]; then
      echo "ok skills repo: up to date with origin/main"
    else
      echo "! skills repo: $behind commit(s) behind origin/main -- run: git pull && make install"
      UPGRADE_PENDING=1
    fi
  else
    echo "x skills repo: could not fetch origin -- check network/remote"
    UPGRADE_PENDING=1
  fi

  if [[ "$UPGRADE_PENDING" -gt 0 ]]; then
    echo "-- updates pending"
    exit 1
  fi
  echo "-- everything up to date"
  exit 0
}

if [[ "$MODE" == "upgrade" ]]; then run_upgrade; fi

# ── main ───────────────────────────────────────────────────────────────────
[[ "$MODE" == "check" ]] && note "$(flowkit_version)"
if [[ $# -gt 0 ]]; then
  for s in "$@"; do sync_one "$s"; done
else
  for d in "$REPO_DIR"/skills/*/; do sync_one "$(basename "$d")"; done
  ensure_flow_link
  ensure_flowkit_link
  scan_orphans "$AGENTS_DIR"
  scan_orphans "$CLAUDE_DIR"
  [[ "$MODE" == "check" ]] && check_harness
fi

# repo hygiene: skills are served from the checked-out branch
BRANCH="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo '?')"
[[ "$BRANCH" != "main" ]] && bad "repo is on branch '$BRANCH' -- symlinks serve it to ALL agents (checkout main)"

if [[ "$PROBLEMS" -gt 0 ]]; then
  echo "-- $PROBLEMS problem(s) found"
  exit 1
fi
if [[ "$MODE" == "check" ]]; then echo "-- chain healthy"; else echo "-- in sync. Skills pick up on next session."; fi
