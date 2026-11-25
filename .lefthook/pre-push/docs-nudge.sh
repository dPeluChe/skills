#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# args = the pushed files. Never blocks BY CONSTRUCTION: one guarded group.
{
  code=0
  docs=0
  for f in "$@"; do
    case "$f" in
      *.md) docs=1 ;;
      src/*|convex/*|app/*|*.ts|*.tsx|*.rs|*.py|*.go) code=1 ;;
    esac
  done
  if [ "$code" -eq 1 ] && [ "$docs" -eq 0 ]; then
    fk_warn "code changed, no docs touched -- check if docs/mds need an update after this change"
  fi
} || true
exit 0
