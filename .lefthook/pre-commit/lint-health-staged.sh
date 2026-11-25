#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# new lint-coverage holes in the staged diff: blanket eslint-disable, rule turned
# off in an eslint config. Advisory. Keep the regexes in sync with lint-health.sh.
# one diff for all JS/TS files, parsed per file: no fork per staged file
out="$(git diff --cached -U0 --diff-filter=ACMR -- \
    '*.js' '*.jsx' '*.ts' '*.tsx' '*.mjs' '*.cjs' '*.json' '*.eslintrc' 2>/dev/null \
  | awk '
    /^\+\+\+ b\// { f = substr($0, 7); next }
    /^\+\+\+ / { f = ""; next }
    /^\+/ && f != "" {
      line = substr($0, 2); sub(/^[ \t]*/, "", line)
      if (f ~ /\.(js|jsx|ts|tsx|mjs|cjs)$/ && line ~ /eslint-disable(-next-line|-line)?[ \t]*(\*\/|--|$)/)
        print "B " f ": " line
      if ((f ~ /eslint\.config\./ || f ~ /\.eslintrc/ || f ~ /(^|\/)package\.json$/) &&
          line ~ /["\047][@A-Za-z0-9_\/.-]+["\047][ \t]*:[ \t]*(["\047]off["\047]|\[[ \t]*["\047]off["\047]|0([^0-9.]|$))/)
        print "O " f ": " line
    }')"
[ -n "$out" ] || exit 0
fk_warn "lint-health: this commit changes lint coverage (advisory, does not block):"
if printf '%s\n' "$out" | grep -q "^B "; then
  fk_warn "  BLANKET disable(s) added -- turn off ALL lint for a file/scope:"
  printf '%s\n' "$out" | sed -n 's/^B /[hooks]   /p' >&2
fi
if printf '%s\n' "$out" | grep -q "^O "; then
  fk_warn "  rule(s) turned OFF in an eslint config:"
  printf '%s\n' "$out" | sed -n 's/^O /[hooks]   /p' >&2
fi
fk_warn "  A scoped, reasoned disable is fine; a blanket one is a false green."
fk_warn "  Full repo audit: flowkit lint-health"
exit 0
