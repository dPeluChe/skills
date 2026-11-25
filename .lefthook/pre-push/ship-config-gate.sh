#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# args = the pushed files. Blocks BY DESIGN when lint/typecheck fail; a crash
# while reading the config falls through to the warning, never a stray 127.
[ "$#" -eq 0 ] && exit 0
only_md=1
for f in "$@"; do
  case "$f" in *.md) ;; *) only_md=0; break ;; esac
done
if [ "$only_md" -eq 1 ]; then
  fk_warn "docs-only push -- lint/typecheck skipped"
  exit 0
fi
root="$(fk_root)"
lint_cmd=""
type_cmd=""
{
  block="$(fk_config_block "$root")"
  lint_cmd="$(printf '%s\n' "$block" | fk_yaml_get lint)"
  type_cmd="$(printf '%s\n' "$block" | fk_yaml_get typecheck)"
} || true
if [ -z "$lint_cmd" ] && [ -z "$type_cmd" ]; then
  fk_warn "=============================================================="
  fk_warn "no preship config block -- pre-push runs without lint"
  fk_warn "add a '## preship config' block (yaml fence with lint:/typecheck:)"
  fk_warn "to CLAUDE.md -- this push goes through UNCHECKED."
  fk_warn "=============================================================="
  exit 0
fi
set +u  # user commands from the config may expand unset vars
rc=0
for key in lint typecheck; do
  if [ "$key" = lint ]; then cmd="$lint_cmd"; else cmd="$type_cmd"; fi
  if [ -n "$cmd" ]; then
    fk_warn "$key: $cmd"
    ( cd "$root" && eval "$cmd" ) || rc=1
  else
    fk_warn "preship config has no $key: key -- $key skipped"
  fi
done
[ "$rc" -ne 0 ] && fk_warn "pre-push FAILED -- fix and push again (never skip the hooks)"
exit "$rc"
