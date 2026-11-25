#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# every PUSHED commit gets the scan, not only what was staged: commits made with
# hooks off (/ship watch, a GUI client) are caught here. stdin = push refs.
command -v gitleaks >/dev/null 2>&1 || {
  fk_warn "gitleaks not installed -- pushed-commit scan SKIPPED"; exit 0; }
rc=0
while read -r _lref lsha _rref rsha; do
  [ -n "$lsha" ] || continue
  case "$lsha" in *[!0]*) ;; *) continue ;; esac
  case "$rsha" in
    *[!0]*) range="$rsha..$lsha" ;;
    *) range="$lsha --not --remotes" ;;
  esac
  fk_gitleaks git --redact --no-banner --log-opts="$range" || rc=1
done
[ "$rc" = 0 ] || fk_warn "secret in a pushed commit -- rotate it, then rewrite or annotate (gitleaks:allow)"
exit "$rc"
