#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# warns about files THIS commit grows past loc_limit; a legacy file the commit
# only touches or shrinks is not the concern. Never blocks.
limit="$(fk_config_get loc_limit)"
case "$limit" in ''|*[!0-9]*) limit=500 ;; esac
git diff --cached --numstat --diff-filter=ACMR | while read -r add del f; do
  case "$add" in ''|*[!0-9]*) continue ;; esac
  case "$del" in ''|*[!0-9]*) del=0 ;; esac
  [ "$add" -gt "$del" ] || continue
  printf '%s\n' "$f" | grep -qiE "$FK_LOC_SKIP" && continue
  # the STAGED version is what gets committed, not the working tree
  n="$(git show ":$f" 2>/dev/null | wc -l | tr -d ' ')"
  if [ -n "$n" ] && [ "$n" -gt "$limit" ]; then
    fk_warn "WARNING: $f has $n lines (>$limit) and this commit grew it (+$((add - del))) -- consider a split. Does not block."
  fi
done
exit 0
