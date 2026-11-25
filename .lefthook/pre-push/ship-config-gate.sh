#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# args = the pushed files. Blocks BY DESIGN when lint/typecheck fail; reading the
# config is guarded, so a crash there falls through to the warning, never a 127.
skip=""
lint_cmd=""
type_cmd=""
root="$(fk_root)"
{
  [ "$#" -eq 0 ] && skip="empty"
  if [ -z "$skip" ]; then
    only_md=1
    for f in "$@"; do
      case "$f" in *.md) ;; *) only_md=0; break ;; esac
    done
    [ "$only_md" -eq 1 ] && skip="docs"
  fi
  lint_cmd="$(fk_config_get lint)"
  type_cmd="$(fk_config_get typecheck)"
} || true
[ "$skip" = "empty" ] && exit 0
if [ "$skip" = "docs" ]; then
  fk_warn "docs-only push -- lint/typecheck skipped"
  exit 0
fi
if [ -z "$lint_cmd" ] && [ -z "$type_cmd" ]; then
  fk_warn "=============================================================="
  fk_warn "no preship config block -- pre-push runs without lint"
  fk_warn "add a '## preship config' block (yaml fence with lint:/typecheck:)"
  fk_warn "to CLAUDE.md -- this push goes through UNCHECKED."
  fk_warn "=============================================================="
  exit 0
fi
set +u
rc=0
if [ -n "$lint_cmd" ]; then
  fk_warn "lint: $lint_cmd"
  ( cd "$root" && eval "$lint_cmd" ) || rc=1
else
  fk_warn "preship config has no lint: key -- lint skipped"
fi
if [ -n "$type_cmd" ]; then
  fk_warn "typecheck: $type_cmd"
  ( cd "$root" && eval "$type_cmd" ) || rc=1
else
  fk_warn "preship config has no typecheck: key -- typecheck skipped"
fi
[ "$rc" -ne 0 ] && fk_warn "pre-push FAILED -- fix and push again (never skip the hooks)"
exit "$rc"
