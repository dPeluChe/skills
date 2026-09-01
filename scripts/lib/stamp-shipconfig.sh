# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (REPO_DIR, note, agent_action, ...) come from util.sh
# ── stamp-shipconfig: the ## ship config block -- stack detection, CI
#    extraction, loc_limit, hooks_skip parsing. Split out of stamp.sh (LOC).
#    Sourced by scripts/install.sh; never executed directly.

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

pkg_scripts() { # $1 = package.json; prints the script NAMES, one per line
  [[ -f "$1" ]] || return 0
  if python3 - "$1" 2>/dev/null <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
for k in (d.get("scripts") or {}):
    print(k)
PY
  then
    return 0
  fi
  # python3 unavailable/failed -> crude grep of the "scripts" object keys
  sed -n '/"scripts"[[:space:]]*:/,/}/p' "$1" 2>/dev/null \
    | grep -oE '"[A-Za-z0-9:_.-]+"[[:space:]]*:' \
    | sed -E 's/^"([^"]+)".*/\1/' \
    | grep -vx 'scripts'
}

detect_npm_framework() { # $1 = package.json; prints Next.js|Vite|"" (best effort
  # from deps + script bodies) to LABEL the suggestion.
  [[ -f "$1" ]] || return 0
  if python3 - "$1" 2>/dev/null <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
deps = {}
for k in ("dependencies", "devDependencies"):
    deps.update(d.get(k) or {})
scripts = " ".join((d.get("scripts") or {}).values())
if "next" in deps or "next" in scripts:
    print("Next.js")
elif "vite" in deps or "vite" in scripts:
    print("Vite")
PY
  then
    return 0
  fi
  grep -q '"next"[[:space:]]*:' "$1" 2>/dev/null && { echo "Next.js"; return 0; }
  grep -q '"vite"[[:space:]]*:' "$1" 2>/dev/null && { echo "Vite"; return 0; }
  return 0
}

detect_typecheck_cmd() { # $1 = package.json; prints the framework-CORRECT typecheck
  # command. `tsc --noEmit` does NOT understand .astro/.vue/.svelte component files
  # -- suggesting it for those stacks is the exact false green /ship warns about
  # (field feedback: an Astro repo got `tsc --noEmit`, which checks none of it).
  [[ -f "$1" ]] || { echo "npx tsc --noEmit"; return 0; }
  python3 - "$1" 2>/dev/null <<'PY' || echo "npx tsc --noEmit"
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("npx tsc --noEmit"); raise SystemExit
deps = {}
for k in ("dependencies", "devDependencies"):
    deps.update(d.get(k) or {})
if "astro" in deps:
    print("astro check")
elif "svelte" in deps or "svelte-check" in deps:
    print("svelte-check")
elif "vue-tsc" in deps or "@vue/language-tools" in deps or "vue" in deps:
    print("vue-tsc --noEmit")
else:
    print("npx tsc --noEmit")
PY
}

npm_ship_lines() { # $1 = target repo; prints "key<TAB>ship-config-line" for
  # lint/typecheck/build/test derived from the REAL package.json scripts.
  # Field case (walter-client): the static npm template suggested `npm run lint`
  # / `npm test` that did not exist there. Now: suggest the scripts actually
  # present, name absent ones explicitly, keep the project-references tsconfig
  # fix for typecheck, and label the stack Next/Vite. No scripts at all -> the
  # generic TODOs (each line says the script is absent).
  local target="$1" pkg="$1/package.json" fw fwc="" scripts s ts_script="" test_script="" tc_cmd=""
  fw="$(detect_npm_framework "$pkg")"
  [[ -n "$fw" ]] && fwc=" [$fw]"
  scripts="$(pkg_scripts "$pkg")"

  if grep -qx 'lint' <<<"$scripts"; then
    printf 'lint\tlint: npm run lint%s # from package.json scripts\n' "$fwc"
  else
    printf 'lint\tlint: # TODO no "lint" script in package.json%s -- add one or omit\n' "$fwc"
  fi

  for s in typecheck type-check tsc; do
    grep -qx "$s" <<<"$scripts" && { ts_script="$s"; break; }
  done
  if [[ -n "$ts_script" ]]; then
    printf 'typecheck\ttypecheck: npm run %s # from package.json scripts\n' "$ts_script"
  elif [[ -f "$target/tsconfig.json" ]] \
       && grep -q '"references"' "$target/tsconfig.json" 2>/dev/null; then
    # a root tsconfig that is a project-references stub ("files": [] +
    # "references": [...]) makes `tsc --noEmit` a NO-OP that passes green while
    # checking nothing -- point at the real project tsconfig instead.
    # Sibling dirs with their OWN tsconfig that the root does NOT reference
    # (convex/, functions/, workers/, server/) are checked by NEITHER
    # `tsc --noEmit` NOR `tsc -b` NOR the framework build -- field case: a repo
    # shipped green with convex/ broken. Chain a -p check per unreferenced sibling.
    sib=""
    for d in convex functions workers server supabase/functions; do
      if [[ -f "$target/$d/tsconfig.json" ]] \
         && ! grep -q "$d" "$target/tsconfig.json" 2>/dev/null; then
        sib="$sib && npx tsc --noEmit -p $d/tsconfig.json"
      fi
    done
    printf 'typecheck\ttypecheck: # TODO root tsconfig is a references stub -- use: npx tsc -b --noEmit%s (plain tsc --noEmit checks NOTHING; -b alone skips unreferenced siblings like convex/)\n' "$sib"
  else
    tc_cmd="$(detect_typecheck_cmd "$pkg")"
    if [[ "$tc_cmd" == "npx tsc --noEmit" ]]; then
      printf 'typecheck\ttypecheck: # TODO e.g. npx tsc --noEmit (no typecheck script in package.json)\n'
    else
      printf 'typecheck\ttypecheck: # TODO e.g. %s -- this stack needs its OWN typechecker; tsc --noEmit does not understand its component files (no typecheck script in package.json)\n' "$tc_cmd"
    fi
  fi

  if grep -qx 'build' <<<"$scripts"; then
    printf 'build\tbuild: npm run build # from package.json scripts\n'
  else
    printf 'build\tbuild: # TODO no "build" script in package.json -- add one or omit\n'
  fi

  for s in test test:run test:ci; do
    grep -qx "$s" <<<"$scripts" && { test_script="$s"; break; }
  done
  if [[ "$test_script" == "test" ]]; then
    printf 'test\ttest: npm test # from package.json scripts\n'
  elif [[ -n "$test_script" ]]; then
    printf 'test\ttest: npm run %s # from package.json scripts\n' "$test_script"
  else
    printf 'test\ttest: # TODO no "test" script in package.json -- add one or omit\n'
  fi
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
  # ONE space before a trailing comment, never aligned padding: prettier collapses
  # runs of spaces in markdown, so an aligned block makes `prettier --check` fail
  # the moment flowkit stamps it. In one repo that check gates deploy, so
  # installing flowkit left the deploy door red. The YAML parses identically.
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
      lint_line='lint: # TODO e.g. cargo fmt --check && cargo clippy -- -D warnings'
      type_line='typecheck: # TODO usually covered by clippy/build'
      build_line='build: # TODO e.g. cargo build'
      test_line='test: # TODO e.g. cargo test'
      ;;
    npm)
      # read the ACTUAL package.json scripts (Next/Vite label, absent-script
      # notes, project-references tsconfig fix) instead of static guesses
      local _k _v
      while IFS=$'\t' read -r _k _v; do
        case "$_k" in
          lint)      lint_line="$_v" ;;
          typecheck) type_line="$_v" ;;
          build)     build_line="$_v" ;;
          test)      test_line="$_v" ;;
        esac
      done < <(npm_ship_lines "$target")
      ;;
    python)
      lint_line='lint: # TODO e.g. ruff check .'
      type_line='typecheck: # TODO e.g. mypy .'
      build_line='build: # TODO omit if none'
      test_line='test: # TODO e.g. pytest'
      ;;
    go)
      lint_line='lint: # TODO e.g. go vet ./...'
      type_line='typecheck: # TODO covered by go build'
      build_line='build: # TODO e.g. go build ./...'
      test_line='test: # TODO e.g. go test ./...'
      ;;
    *)
      lint_line='lint: # TODO e.g. npm run lint'
      type_line='typecheck: # TODO e.g. npx tsc --noEmit'
      build_line='build: # TODO e.g. npm run build'
      test_line='test: # TODO omit if none'
      ;;
  esac
  # better than guessing: real commands already exercised by CI
  if hit="$(ci_grep_cmd "$target" '(^|[[:space:]/-])(lint|eslint|ruff check|clippy|fmt --check|golangci-lint)')"; then
    from="${hit#*$'\t'}"; lint_line="lint: ${hit%%$'\t'*} # from $from -- verify"; ci_used=1
  fi
  if hit="$(ci_grep_cmd "$target" '(tsc|typecheck|type-check|mypy|go vet)')"; then
    from="${hit#*$'\t'}"; type_line="typecheck: ${hit%%$'\t'*} # from $from -- verify"; ci_used=1
  fi
  if hit="$(ci_grep_cmd "$target" '(^|[[:space:]])[[:alnum:]_ -]*build')"; then
    from="${hit#*$'\t'}"; build_line="build: ${hit%%$'\t'*} # from $from -- verify"; ci_used=1
  fi
  if hit="$(ci_grep_cmd "$target" '(^|[[:space:]])(test|pytest|jest|vitest)')"; then
    from="${hit#*$'\t'}"; test_line="test: ${hit%%$'\t'*} # from $from -- verify"; ci_used=1
  fi

  # If CLAUDE.md already documents a max-lines-per-file convention, honor IT
  # instead of the 500 default -- else the stamp overrides a rule the repo
  # already wrote and every repo corrects it by hand (field: two repos said
  # 400, stamp put 500). Take the largest 3-4 digit number on a line that
  # mentions both a limit word and "line/línea" (the max, not the warn-at).
  local loc_limit="500" loc_note=""
  if [[ -f "$cmd" ]]; then
    local found
    found="$( { grep -iE '(m[aá]x|limit|l[ií]mite|per file|por archivo)' "$cmd" 2>/dev/null \
      | grep -iE 'l[ií]nea|line' \
      | grep -oE '[0-9]{3,4}' | sort -rn | head -1; } || true)"
    if [[ -n "$found" ]]; then
      loc_limit="$found"
      loc_note="   # from CLAUDE.md's documented convention"
      note "-> ship config loc_limit=$found taken from CLAUDE.md convention (not the 500 default)"
    fi
  fi

  cat >> "$cmd" <<EOF

## ship config

\`\`\`yaml
$lint_line
$type_line
$build_line
$test_line
merge_policy: ask # auto | ask
loc_limit: $loc_limit$loc_note
simplify: 500 # run /simplify only if changed LOC > N (off = only on request)
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

