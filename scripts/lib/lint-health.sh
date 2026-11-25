# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (TARGET_REPO, LINT_MEASURE, ...) come from install.sh
# lint-health: alert on false-green lint gates in JS/TS repos (sourced by install.sh).
# A scoped, reasoned suppression is fine; a blanket one is a false green. Advisory.

# Source dirs to scan for disables (skip node_modules/dist/generated); falls
# back to the repo root when none of the conventional dirs exist.
_lh_src_dirs() { # $1 = target
  local target="$1" d found=0
  for d in src app convex lib pages components server; do
    [[ -d "$target/$d" ]] && { printf '%s\n' "$target/$d"; found=1; }
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' "$target"
}

# one source file for `eslint --print-config`; tests/migrations are skipped because
# their scoped overrides misrepresent the repo-wide severity
_lh_sample_src() { # $1 = target; prints one source file, or nothing
  local target="$1" d f
  while IFS= read -r d; do
    f="$(find "$d" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' \
      -o -name '*.jsx' \) 2>/dev/null \
      | grep -viE 'test|spec|\.d\.ts|migrat|/__|/dist/|/node_modules/' | head -1 || true)"
    [[ -n "$f" ]] && { printf '%s\n' "$f"; return 0; }
  done < <(_lh_src_dirs "$target")
  return 0
}

_LH_GREP_OPTS=(-rnE --include='*.js' --include='*.jsx' --include='*.ts'
  --include='*.tsx' --include='*.mjs' --include='*.cjs'
  --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build
  --exclude-dir=.next --exclude-dir=out --exclude-dir=coverage
  --exclude-dir=_generated --exclude-dir=generated)

# usual ignore targets that are FINE to exclude from lint (build output, deps,
# generated code) -- anything else in an ignore list may be hiding source
_lh_is_usual() { # $1 = ignore entry; 0 = usual (safe), 1 = flag it
  printf '%s' "$1" | grep -qiE \
    'node_modules|dist|build|\.next|(^|/)out(/|$)|coverage|_generated|/?generated|\.min\.|vendor|public|\.turbo|storybook-static|\.d\.ts' \
    && return 0
  return 1
}

# ── headline audit (flowkit lint-health [path]) ─────────────────────────────
_lh_rule_on() { # $1 = eslint --print-config JSON, $2 = rule. 0 = on (warn/error)
  printf '%s' "$1" | python3 -c '
import json, sys
try: cfg = json.load(sys.stdin)
except Exception: raise SystemExit(1)
v = cfg.get("rules", {}).get(sys.argv[1])
s = v[0] if isinstance(v, list) else v
raise SystemExit(0 if s in (1, 2, "warn", "error") else 1)
' "$2" 2>/dev/null
}

_lh_substitute() { # $1 = base rule; prints the rule that REPLACES it in TS repos.
  # typescript-eslint turns the base rule off on purpose and its extension on;
  # reporting the base rule as a gap would ask for duplicate rules
  case "$1" in
    no-unused-vars)                 echo "@typescript-eslint/no-unused-vars" ;;
    unused-imports/no-unused-vars)  echo "unused-imports/no-unused-imports" ;;
    no-shadow)                      echo "@typescript-eslint/no-shadow" ;;
    no-redeclare)                   echo "@typescript-eslint/no-redeclare" ;;
    no-use-before-define)           echo "@typescript-eslint/no-use-before-define" ;;
    no-unused-expressions)          echo "@typescript-eslint/no-unused-expressions" ;;
    no-empty-function)              echo "@typescript-eslint/no-empty-function" ;;
    no-implied-eval)                echo "@typescript-eslint/no-implied-eval" ;;
    require-await)                  echo "@typescript-eslint/require-await" ;;
    dot-notation)                   echo "@typescript-eslint/dot-notation" ;;
    *) return 1 ;;
  esac
}

run_lint_health() {
  local target="${1:-.}"
  target="$(cd "$target" 2>/dev/null && pwd)" || die "lint-health: not a directory: ${1:-.}"

  # Guard: an eslint config (any of 3 shapes) OR a package.json "lint" script.
  local -a cfg_paths=(); local has_cfg=0 has_lint=0 f
  for f in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts \
           .eslintrc.json .eslintrc.js .eslintrc.cjs .eslintrc.yml .eslintrc.yaml .eslintrc; do
    [[ -f "$target/$f" ]] && { cfg_paths+=("$target/$f"); has_cfg=1; }
  done
  if [[ -f "$target/package.json" ]]; then
    grep -qE '"eslintConfig"[[:space:]]*:' "$target/package.json" 2>/dev/null \
      && { cfg_paths+=("$target/package.json"); has_cfg=1; }
    grep -qE '"lint"[[:space:]]*:' "$target/package.json" 2>/dev/null && has_lint=1
  fi
  if [[ "$has_cfg" -eq 0 && "$has_lint" -eq 0 ]]; then
    echo "no eslint config -- lint-health N/A"
    exit 0
  fi

  echo "-- lint-health ($target)"

  local -a dirs=(); local d
  while IFS= read -r d; do dirs+=("$d"); done < <(_lh_src_dirs "$target")

  # ── blanket disables (headline): directive with NO rule name after it ──────
  # /* eslint-disable */ , // eslint-disable(-next-line|-line) at line end, or a
  # directive followed only by a `--` reason -- all turn off ALL rules in scope.
  local blanket all_dir
  blanket="$(grep "${_LH_GREP_OPTS[@]}" \
    'eslint-disable(-next-line|-line)?[[:space:]]*(\*/|--|$)' "${dirs[@]}" 2>/dev/null || true)"
  all_dir="$(grep "${_LH_GREP_OPTS[@]}" 'eslint-disable' "${dirs[@]}" 2>/dev/null || true)"

  local blanket_n total_n reasoned_n unreasoned_n alert=0
  blanket_n="$(printf '%s' "$blanket" | grep -c . || true)"
  total_n="$(printf '%s' "$all_dir" | grep -c . || true)"
  reasoned_n="$(printf '%s' "$all_dir" | grep -cE 'eslint-disable[^*]*--' || true)"
  unreasoned_n=$(( total_n - reasoned_n ))

  if [[ "$blanket_n" -gt 0 ]]; then
    alert=1
    echo "  ! $blanket_n blanket disable(s) -- these turn off ALL lint for a file/scope:"
    printf '%s\n' "$blanket" | while IFS= read -r line; do
      [[ -n "$line" ]] && echo "      ${line#"$target"/}"
    done
  else
    echo "  ok no blanket disables (every eslint-disable names a rule)"
  fi

  # text grep finds candidates but cannot tell repo-wide from a scoped `files:`
  # override; eslint --print-config on a real source file decides
  local off_rules="" cfg rule
  for cfg in ${cfg_paths[@]+"${cfg_paths[@]}"}; do
    while IFS= read -r rule; do
      [[ -n "$rule" ]] || continue
      off_rules+="$rule|$(basename "$cfg")"$'\n'
    done < <(grep -hoE \
      "['\"][@A-Za-z0-9_/.-]+['\"][[:space:]]*:[[:space:]]*(['\"]off['\"]|\[[[:space:]]*['\"]off['\"]|0\b)" \
      "$cfg" 2>/dev/null | grep -oE "^['\"][^'\"]+['\"]" | tr -d "\"'" || true)
  done

  local verified=0 scoped="" covered=""
  if [[ -n "$off_rules" && -x "$target/node_modules/.bin/eslint" ]]; then
    local sample printcfg
    sample="$(_lh_sample_src "$target")"
    if [[ -n "$sample" ]]; then
      printcfg="$( cd "$target" && "$target/node_modules/.bin/eslint" \
        --print-config "$sample" 2>/dev/null )" || true
      if [[ "${printcfg:0:1}" == "{" ]]; then
        verified=1
        local kept="" r c sub
        while IFS='|' read -r r c; do
          [[ -n "$r" ]] || continue
          if _lh_rule_on "$printcfg" "$r"; then
            scoped+="$r "                      # ON for source => scoped override
            continue
          fi
          # off, but is the job done by its TS-aware replacement (or the compiler)?
          if sub="$(_lh_substitute "$r")" && _lh_rule_on "$printcfg" "$sub"; then
            covered+="$r -> $sub"$'\n'
            continue
          fi
          if [[ "$r" == "no-undef" ]] && compgen -G "$target/tsconfig*.json" >/dev/null 2>&1; then
            covered+="no-undef -> tsc (TS2304), not eslint, in a TypeScript repo"$'\n'
            continue
          fi
          kept+="$r|$c"$'\n'
        done < <(printf '%s' "$off_rules" | sort -u)
        off_rules="$kept"
      fi
    fi
  fi

  local off_n
  off_n="$(printf '%s' "$off_rules" | grep -c . || true)"
  if [[ "$off_n" -gt 0 ]]; then
    alert=1
    if [[ "$verified" -eq 1 ]]; then
      echo "  ! $off_n rule(s) OFF repo-wide (verified via eslint --print-config):"
    else
      echo "  ! $off_n rule(s) OFF in the config TEXT -- a text read cannot tell repo-wide"
      echo "    from a scoped 'files:' override; verify with: eslint --print-config <src file>"
    fi
    printf '%s' "$off_rules" | sort -u | while IFS='|' read -r rule cfg; do
      [[ -n "$rule" ]] && echo "      $rule (in $cfg)"
    done
  else
    echo "  ok no rules disabled repo-wide in eslint config"
  fi
  if [[ -n "$scoped" ]]; then
    echo "  - scoped override(s), OFF only for some files but ON for source (fine): ${scoped% }"
  fi
  if [[ -n "$covered" ]]; then
    echo "  - base rule(s) off because something else covers them (fine, do NOT re-enable:"
    echo "    turning them back on duplicates the check and adds TS false positives):"
    printf '%s' "$covered" | while IFS= read -r line; do
      [[ -n "$line" ]] && echo "      $line"
    done
  fi

  # ── unreasoned disables (info; reasoned scoped ones are fine) ──────────────
  if [[ "$unreasoned_n" -gt 0 ]]; then
    echo "  - $unreasoned_n of $total_n disable directive(s) carry no \`-- reason\` (info; add a reason)"
  fi

  # ── ignored source paths (flag only non-standard entries) ──────────────────
  local ignored="" entry
  if [[ -f "$target/.eslintignore" ]]; then
    while IFS= read -r entry; do
      entry="${entry%%#*}"; entry="${entry## }"; entry="${entry%% }"
      [[ -n "$entry" ]] || continue
      _lh_is_usual "$entry" || ignored+=".eslintignore: $entry"$'\n'
    done < "$target/.eslintignore"
  fi
  for cfg in ${cfg_paths[@]+"${cfg_paths[@]}"}; do
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      _lh_is_usual "$entry" || ignored+="$(basename "$cfg"): $entry"$'\n'
    done < <(grep -hE 'globalIgnores[[:space:]]*\(|ignorePatterns[[:space:]]*[:=]' "$cfg" 2>/dev/null \
      | grep -oE "['\"][^'\"]+['\"]" | tr -d "\"'" || true)
  done
  local ign_n
  ign_n="$(printf '%s' "$ignored" | grep -c . || true)"
  if [[ "$ign_n" -gt 0 ]]; then
    echo "  ! $ign_n ignore entr(y/ies) may cover SOURCE (not the usual build/dep output):"
    printf '%s' "$ignored" | sort -u | while IFS= read -r entry; do
      [[ -n "$entry" ]] && echo "      $entry"
    done
  fi

  echo "--"
  if [[ "$alert" -eq 1 ]]; then
    echo "ALERT: lint coverage has holes (blanket disables and/or off-rules above)."
    echo "  A scoped, reasoned disable is fine; a blanket/unreasoned one is a false green."
    echo "  Advisory only -- this never blocks a commit. Measure a rule: flowkit lint-health --measure '<rule>'"
  else
    echo "ok lint-health: no blanket disables, no off-rules -- lint gate looks honest"
  fi
  exit 0
}

# --measure '<rule>': count findings with <rule> forced on, mutating nothing. Flat
# config extends the repo config from a temp file (--rule silently skips plugin
# rules there). Any failure is inconclusive, never 0. See docs/ARCHITECTURE/FLOWKIT_INTERNALS.md
run_lint_measure() {
  # A count nobody can reproduce is not actionable: the field report could not
  # verify "13 findings" for no-undef and had no way to see WHICH files, so the
  # only options left were trust it or ignore it. --list prints the findings.
  local rule="$1" target="${2:-.}" bin="" want_list=0
  if [[ "$target" == "--list" ]]; then want_list=1; target="${3:-.}"
  elif [[ "${3:-}" == "--list" ]]; then want_list=1; fi
  target="$(cd "$target" 2>/dev/null && pwd)" || die "lint-health: not a directory: ${2:-.}"
  [[ -n "$rule" ]] || die "lint-health --measure: needs a rule name"

  if [[ -x "$target/node_modules/.bin/eslint" ]]; then
    bin="$target/node_modules/.bin/eslint"
  else
    echo "eslint not runnable in $target (no node_modules/.bin/eslint) -- run npm install, then retry. measure skipped."
    exit 0
  fi

  local -a paths=(); local d
  while IFS= read -r d; do paths+=("$d"); done < <(_lh_src_dirs "$target")

  # importable flat config (.js/.mjs/.cjs) -> extend it; else fall back to --rule
  # (legacy .eslintrc, a .ts flat config we cannot import, or package.json)
  local flat="" f
  for f in eslint.config.js eslint.config.mjs eslint.config.cjs; do
    [[ -f "$target/$f" ]] && { flat="$target/$f"; break; }
  done

  local out="" err="" method="rule"
  if [[ -n "$flat" ]]; then
    method="extended"
    local tmpdir tmpcfg
    tmpdir="$(mktemp -d)"; tmpcfg="$tmpdir/measure.mjs"
    # abs-path import: base config's own plugin specifiers resolve from the repo
    # (correct); we append one rule override. Temp lives in /tmp -- no mutation.
    {
      printf "import base from %s\n" "'$flat'"
      printf "export default [...(Array.isArray(base)?base:[base]), { rules: { %s: 'error' } }]\n" "'$rule'"
    } > "$tmpcfg"
    out="$( cd "$target" && "$bin" "${paths[@]}" --config "$tmpcfg" --format json 2>"$tmpdir/err" )" || true
    err="$(cat "$tmpdir/err" 2>/dev/null || true)"
    rm -rf "$tmpdir"
  else
    out="$( cd "$target" && "$bin" "${paths[@]}" \
      --rule "{\"$rule\":\"error\"}" --format json 2>/dev/null )" || true
  fi

  # ${out:0:1} not `printf|head -c1|grep`: under `set -o pipefail` head closes the
  # pipe after 1 byte -> printf takes SIGPIPE (141) -> the pipeline reports failure
  # even when grep matched (the measuring instrument lies). Pure-bash slice is safe.
  if [[ -z "$out" || "${out:0:1}" != "[" ]]; then
    if printf '%s' "$err" | grep -qiE 'definition for rule|could not find|not found'; then
      echo "'$rule' is unknown to this config (rule/plugin not registered here). measure inconclusive."
    else
      echo "eslint could not produce a report for '$rule' (config error). measure inconclusive."
    fi
    exit 0
  fi

  local counts
  counts="$(printf '%s' "$out" | python3 -c '
import json, sys
rule = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    print("ERR"); raise SystemExit
findings = 0; files = 0
for res in data:
    hits = sum(1 for m in res.get("messages", []) if m.get("ruleId") == rule)
    if hits:
        findings += hits; files += 1
print(f"{findings} {files}")
' "$rule" 2>/dev/null || echo ERR)"

  if [[ "$counts" == "ERR" || -z "$counts" ]]; then
    echo "could not parse eslint output for '$rule'. measure inconclusive."
    exit 0
  fi
  echo "$rule forced on: ${counts% *} findings across ${counts#* } files (via ${method} config)"
  if [[ "$want_list" == 1 ]]; then
    printf '%s' "$out" | python3 -c '
import json, os, sys
rule = sys.argv[1]; root = sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit
for res in data:
    path = res.get("filePath", "")
    if os.path.isabs(path):
        path = os.path.relpath(path, root)
    for m in res.get("messages", []):
        if m.get("ruleId") == rule:
            print("  %s:%s:%s  %s" % (path, m.get("line", 0), m.get("column", 0), m.get("message", "")))
' "$rule" "$target" 2>/dev/null || echo "  (could not list findings)"
  else
    echo "  see them: flowkit lint-health --measure '$rule' --list ${2:-.}"
  fi
  exit 0
}

