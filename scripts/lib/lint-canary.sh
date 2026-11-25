# shellcheck shell=bash
# shellcheck disable=SC2154  # globals come from install.sh
# --canary: plant one violation per extension present and run the repo's OWN lint.
# Blind only when a catching rule is on; a parse error is its own finding, never
# proof the lint ran. The four design traps: docs/ARCHITECTURE/FLOWKIT_INTERNALS.md
_lh_pkg_script() { # $1 = target, $2 = script name; prints scripts.<name> or empty
  python3 -c '
import json, sys
try: s = json.load(open(sys.argv[1] + "/package.json")).get("scripts", {})
except Exception: raise SystemExit
print(s.get(sys.argv[2], ""))
' "$1" "$2" 2>/dev/null || true
}

_lh_present_exts() { # $1 = target; unique lintable extensions present in source
  local d
  for d in $(_lh_src_dirs "$1"); do find "$d" -type f 2>/dev/null; done \
    | grep -viE 'test|spec|\.d\.ts|/node_modules/|/dist/|__flowkit_canary__' \
    | grep -oiE '\.(ts|tsx|js|jsx|mjs|cjs|astro|vue|svelte)$' \
    | tr '[:upper:]' '[:lower:]' | sed 's/^\.//' | sort -u
}

_lh_sample_of_ext() { # $1 = target, $2 = ext; a real (non-test) file of that ext
  local target="$1" ext="$2" d f
  while IFS= read -r d; do
    f="$(find "$d" -type f -iname "*.$ext" 2>/dev/null \
      | grep -viE 'test|spec|__flowkit_canary__' | head -1 || true)"
    [[ -n "$f" ]] && { printf '%s\n' "$f"; return 0; }
  done < <(_lh_src_dirs "$target")
  return 0
}

_lh_canary_content() { # $1 = ext; a file body with a blatant, common-rule violation
  case "$1" in
    astro)       printf -- '---\ndebugger\nconsole.log("flowkit canary")\n---\n<div></div>\n' ;;
    vue|svelte)  printf -- '<script>\ndebugger\nconsole.log("flowkit canary")\n</script>\n<template><div></div></template>\n' ;;
    *)           printf -- '/* flowkit canary -- delete if committed */\ndebugger\nconsole.log("flowkit canary")\n' ;;
  esac
}

_lh_ext_has_on_rule() { # $1 = eslint bin, $2 = target, $3 = sample file. 0 only when
  # a rule the canary WOULD trip (no-debugger/no-console) is confirmed ON -- so a
  # BLIND verdict is never a false accusation on a repo that turned those off.
  local bin="$1" target="$2" sample="$3" pc
  [[ -x "$bin" ]] || return 1
  pc="$( cd "$target" && "$bin" --print-config "$sample" 2>/dev/null )" || return 1
  [[ "${pc:0:1}" == "{" ]] || return 1
  printf '%s' "$pc" | python3 -c '
import json, sys
try: r = json.load(sys.stdin).get("rules", {})
except Exception: sys.exit(1)
def on(n):
    v = r.get(n); s = v[0] if isinstance(v, list) else v
    return s in (1, 2, "warn", "error")
sys.exit(0 if (on("no-debugger") or on("no-console")) else 1)
' 2>/dev/null
}

run_lint_canary() {
  local target="${1:-.}"
  target="$(cd "$target" 2>/dev/null && pwd)" || die "lint-health: not a directory: ${1:-.}"

  local lint_cmd=""
  [[ -f "$target/package.json" ]] && lint_cmd="$(_lh_pkg_script "$target" lint)"
  if [[ -z "$lint_cmd" ]]; then
    echo "no \"lint\" script in package.json -- the canary runs the repo's OWN gate, so there's nothing to probe. N/A"
    exit 0
  fi
  local eslint_bin=""
  [[ -x "$target/node_modules/.bin/eslint" ]] && eslint_bin="$target/node_modules/.bin/eslint"

  echo "-- lint-canary ($target): does the repo's lint CATCH a planted violation per extension?"
  echo "   gate: $lint_cmd"

  local -a exts=(); local e
  while IFS= read -r e; do exts+=("$e"); done < <(_lh_present_exts "$target")
  if [[ "${#exts[@]}" -eq 0 ]]; then echo "  no source files to probe. N/A"; exit 0; fi

  local planted="" ext sample canary
  # Ctrl-C mid-lint must not leave probes in the repo's source dirs
  trap 'printf "%s" "$planted" | cut -d"|" -f2 | while IFS= read -r c; do rm -f "$c"; done' EXIT INT TERM
  for ext in "${exts[@]}"; do
    sample="$(_lh_sample_of_ext "$target" "$ext")"
    [[ -n "$sample" ]] || continue
    canary="$(dirname "$sample")/__flowkit_canary__.$ext"
    if _lh_canary_content "$ext" > "$canary" 2>/dev/null; then
      planted+="$ext|$canary|$sample"$'\n'
    else
      rm -f "$canary"
    fi
  done
  if [[ -z "$planted" ]]; then echo "  could not plant probes. N/A"; exit 0; fi

  # trap 1: run the repo's OWN command, with node_modules/.bin on PATH exactly as
  # npm would -- so `eslint`/`astro`/etc. resolve like they do in `npm run lint`.
  local out
  out="$( cd "$target" && PATH="$target/node_modules/.bin:$PATH" sh -c "$lint_cmd" 2>&1 )" || true

  local alert=0 bn fre block
  while IFS='|' read -r ext canary sample; do
    [[ -n "$ext" ]] || continue
    bn="__flowkit_canary__.$ext"
    # the eslint report block for THIS probe: its filename line + the indented
    # findings under it, until the next file. Boundary after the name so a .ts
    # probe never grabs the .tsx block ('.' escaped for the awk regex).
    fre="$(printf '%s' "$bn" | sed 's/\./\\./g')"
    block="$(printf '%s' "$out" | awk -v f="$fre" \
      '$0 ~ (f "([^A-Za-z0-9]|$)") { g=1; print; next } g && /^[^[:space:]]/ { g=0 } g { print }')"
    if [[ -z "$block" ]]; then
      # not in the report at all -> BLIND, but only when a rule the probe trips
      # is actually ON (never a false accusation on a repo that turned it off).
      if _lh_ext_has_on_rule "$eslint_bin" "$target" "$sample"; then
        alert=1
        echo "  ! $ext: BLIND -- planted a violation next to a real .$ext file and the gate did NOT catch it. .$ext is not being linted (check the script's globs + the parser)."
      else
        echo "  - $ext: inconclusive -- no rule the probe would trip is ON for this file"
      fi
    elif printf '%s' "$block" | grep -qi "parsing error"; then
      alert=1
      echo "  ! $ext: PARSE ERROR on a planted probe -- the linter cannot parse .$ext (its own finding, NOT a pass)"
    else
      echo "  ok $ext: a planted violation was caught -- .$ext files are actually linted"
    fi
    rm -f "$canary"
  done <<< "$planted"

  echo "--"
  if [[ "$alert" -eq 1 ]]; then
    echo "ALERT: the lint gate is GREEN but not catching planted violations in the flagged extension(s)."
    echo "  A green lint proves nothing if the linter never reached those files. Advisory -- never blocks."
  else
    echo "ok lint-canary: every extension present is actually caught by the lint gate"
  fi
  exit 0
}
