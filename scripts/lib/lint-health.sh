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

  # ── rules turned off in config (best-effort; text-based for flat JS) ───────
  local off_rules="" cfg rule
  for cfg in ${cfg_paths[@]+"${cfg_paths[@]}"}; do
    while IFS= read -r rule; do
      [[ -n "$rule" ]] || continue
      off_rules+="$rule|$(basename "$cfg")"$'\n'
    done < <(grep -hoE \
      "['\"][@A-Za-z0-9_/.-]+['\"][[:space:]]*:[[:space:]]*(['\"]off['\"]|\[[[:space:]]*['\"]off['\"]|0\b)" \
      "$cfg" 2>/dev/null | grep -oE "^['\"][^'\"]+['\"]" | tr -d "\"'" || true)
  done
  local off_n
  off_n="$(printf '%s' "$off_rules" | grep -c . || true)"
  if [[ "$off_n" -gt 0 ]]; then
    alert=1
    echo "  ! $off_n rule(s) turned OFF repo-wide in config (text-based read):"
    printf '%s' "$off_rules" | sort -u | while IFS='|' read -r rule cfg; do
      [[ -n "$rule" ]] && echo "      $rule (in $cfg)"
    done
  else
    echo "  ok no rules disabled in eslint config"
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
# Force the rule to error via the repo's OWN eslint + config (so plugins load),
# WITHOUT editing any config, and count findings. Never mutates the repo.
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

  local out
  out="$( cd "$target" && "$bin" "${paths[@]}" \
    --rule "{\"$rule\":\"error\"}" --format json 2>/dev/null )" || true
  if [[ -z "$out" ]] || ! printf '%s' "$out" | head -c1 | grep -q '\['; then
    echo "eslint could not produce a report for '$rule' (config error, or the rule/plugin is unknown to this config). measure inconclusive."
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
  echo "$rule forced on: ${counts% *} findings across ${counts#* } files"
  exit 0
}
