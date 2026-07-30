# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (REPO_DIR, ...) come from install.sh
# ── stamp: per-repo stamps -- gitleaks baseline, FLOW import, ship config ──
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

ship_config_block() { # $1 = target repo; prints the ship config yaml fence body
  # shellcheck disable=SC2016  # backtick fences are literal, not expansions
  sed -n '/^## ship config$/,/^## /p' "$1/CLAUDE.md" 2>/dev/null \
    | sed -n '/^```yaml$/,/^```$/p' | sed '1d;$d'
}

ship_hooks_skip_reason() { # $1 = target repo, $2 = hook name; prints the reason
  # a hook is consciously skipped, declared inside the ship config yaml fence
  # of CLAUDE.md -- empty when the hook is not skipped. BOTH forms are read:
  #   hooks_skip: pre-push: "reason"     (historical one-liner)
  #   hooks_skip:                        (nested map -- plain YAML)
  #     pre-push: "reason"
  local block reason
  block="$(ship_config_block "$1")"
  reason="$(printf '%s\n' "$block" \
    | sed -n "s/^hooks_skip:[[:space:]]*$2:[[:space:]]*//p" | head -1)"
  if [[ -z "$reason" ]]; then
    reason="$(printf '%s\n' "$block" | awk -v hook="$2" '
      /^hooks_skip:[[:space:]]*(#.*)?$/ { inmap = 1; next }
      inmap && /^[^ \t]/ { inmap = 0 }
      inmap {
        line = $0
        sub(/^[ \t]+/, "", line)
        if (index(line, hook ":") == 1) {
          sub(/^[^:]*:[[:space:]]*/, "", line)
          print line
          exit
        }
      }
    ')"
  fi
  printf '%s\n' "$reason" \
    | sed 's/[[:space:]]*#.*$//; s/^["'"'"']//; s/["'"'"']$//; s/[[:space:]]*$//' \
    | head -1
}

ship_hooks_skip_unparseable() { # $1 = target repo; 0 when a hooks_skip key is
  # present but matches NEITHER accepted form (e.g. a flow list `[pre-push]`).
  # A security declaration must never be discarded in silence -- verify WARNs.
  local block
  block="$(ship_config_block "$1")"
  printf '%s\n' "$block" | grep -q '^hooks_skip:' || return 1
  printf '%s\n' "$block" \
    | grep -Eq '^hooks_skip:[[:space:]]*[A-Za-z][A-Za-z-]*:[[:space:]]*[^[:space:]]' \
    && return 1
  printf '%s\n' "$block" | awk '
    /^hooks_skip:[[:space:]]*(#.*)?$/ { inmap = 1; next }
    inmap && /^[^ \t]/ { inmap = 0 }
    inmap && /^[ \t]+[A-Za-z][A-Za-z-]*:[[:space:]]*[^[:space:]]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' && return 1
  return 0
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
      # A root tsconfig that is a project-references stub ("files": [] +
      # "references": [...]) makes `tsc --noEmit` a NO-OP that passes green
      # while checking nothing -- a false green, worse than no check. Point at
      # the real project tsconfig instead.
      if [[ -f "$target/tsconfig.json" ]] \
         && grep -q '"references"' "$target/tsconfig.json" 2>/dev/null; then
        _tsref=""
        for _f in "$target"/tsconfig.*.json; do
          [[ -f "$_f" ]] || continue
          case "$_f" in *node*) continue ;; esac
          _tsref="${_f##*/}"; break
        done
        type_line="typecheck:       # TODO root tsconfig is a references stub -- use: npx tsc --noEmit -p ${_tsref:-tsconfig.app.json} (plain tsc --noEmit checks NOTHING here)"
      else
        type_line='typecheck:       # TODO e.g. npx tsc --noEmit'
      fi
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

docs_is_published_site() { # $1 = target: docs/ serves a live website (GitHub
  # Pages & co.) -- reorganizing it breaks live URLs.
  local t="$1" f
  for f in CNAME index.html _config.yml; do
    [[ -e "$t/docs/$f" ]] && return 0
  done
  grep -qsE 'actions/(configure-pages|deploy-pages|jekyll)|github-pages|mkdocs gh-deploy' \
    "$t"/.github/workflows/*.yml "$t"/.github/workflows/*.yaml 2>/dev/null
}
