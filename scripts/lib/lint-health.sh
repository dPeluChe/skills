# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (TARGET_REPO, LINT_MEASURE, ...) come from install.sh
# ── lint-health: alert on false-green lint gates in JS/TS/React repos ───────
# Sourced by scripts/install.sh (the entrypoint); never executed directly.
#
# Doctrine (same as gitleaks:allow): a scoped, REASONED suppression is fine; a
# BLANKET or UNREASONED one is a false green -- a gate that stopped checking.
# This module ALERTS, never auto-fixes, and never blocks (advisory, exit 0).

# Source dirs to scan for disables (skip node_modules/dist/generated); falls
# back to the repo root when none of the conventional dirs exist.
_lh_src_dirs() { # $1 = target
  local target="$1" d found=0
  for d in src app convex lib pages components server; do
    [[ -d "$target/$d" ]] && { printf '%s\n' "$target/$d"; found=1; }
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' "$target"
}

# One representative SOURCE file for `eslint --print-config` (authoritative rule
# severity). Skip test/spec/migration files -- those are exactly where a scoped
# `files:` override may legitimately turn a rule off, so they misrepresent the
# repo-wide severity.
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

  # ── rules turned off in config. Text grep = CANDIDATES; eslint --print-config
  # = authoritative. The text read finds a `"rule": "off"` anywhere, but CANNOT
  # tell a repo-wide off from a scoped `files:` override (field bug, tennispro:
  # no-explicit-any is error repo-wide, off only in 3 migration scripts + reason).
  # So when eslint runs, we keep only rules ACTUALLY off for a representative
  # source file, and surface the scoped ones separately as fine.
  local off_rules="" cfg rule
  for cfg in ${cfg_paths[@]+"${cfg_paths[@]}"}; do
    while IFS= read -r rule; do
      [[ -n "$rule" ]] || continue
      off_rules+="$rule|$(basename "$cfg")"$'\n'
    done < <(grep -hoE \
      "['\"][@A-Za-z0-9_/.-]+['\"][[:space:]]*:[[:space:]]*(['\"]off['\"]|\[[[:space:]]*['\"]off['\"]|0\b)" \
      "$cfg" 2>/dev/null | grep -oE "^['\"][^'\"]+['\"]" | tr -d "\"'" || true)
  done

  local verified=0 scoped=""
  if [[ -n "$off_rules" && -x "$target/node_modules/.bin/eslint" ]]; then
    local sample printcfg
    sample="$(_lh_sample_src "$target")"
    if [[ -n "$sample" ]]; then
      printcfg="$( cd "$target" && "$target/node_modules/.bin/eslint" \
        --print-config "$sample" 2>/dev/null )" || true
      if [[ "${printcfg:0:1}" == "{" ]]; then
        verified=1
        local kept="" r c sev
        while IFS='|' read -r r c; do
          [[ -n "$r" ]] || continue
          sev="$(printf '%s' "$printcfg" | python3 -c '
import json, sys
try: cfg = json.load(sys.stdin)
except Exception: print("?"); raise SystemExit
v = cfg.get("rules", {}).get(sys.argv[1])
s = v[0] if isinstance(v, list) else v
print(1 if s in (1, 2, "warn", "error") else 0)
' "$r" 2>/dev/null || echo 0)"
          if [[ "$sev" == "1" ]]; then scoped+="$r "   # ON for source => scoped override
          else kept+="$r|$c"$'\n'; fi
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

# ── --measure '<rule>': how much would turning <rule> on reveal? ─────────────
# Force <rule> to error using the repo's OWN eslint + config (plugins load), count
# findings, mutate NOTHING. Flat config: a temp config in /tmp that EXTENDS the
# repo's config (imported by abs path) and overrides only <rule> -- the CLI --rule
# flag silently FAILS to enforce PLUGIN rules under flat config (reports 0 for a
# rule it never ran = false green), so extending is the only honest method there.
# Legacy .eslintrc: --rule works, use it. Any failure -> "inconclusive", never 0.
run_lint_measure() {
  local rule="$1" target="${2:-.}" bin=""
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
  exit 0
}
