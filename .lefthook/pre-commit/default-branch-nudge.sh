#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# most repos here use a branch + PR; warn, never block. Opt out with
# default_branch_ok: true in the preship config.
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo)"
def="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
if [ -z "$def" ]; then
  for b in main master; do
    git show-ref --verify --quiet "refs/heads/$b" && { def="$b"; break; }
  done
fi
ok="$(fk_config_get default_branch_ok | tr -d '[:space:]')"
if [ "$ok" != "true" ] && [ -n "$branch" ] && [ "$branch" = "$def" ]; then
  fk_warn "committing directly to '$branch' (the default branch) -- most repos here use a feature branch + PR."
  fk_warn "  If that's wrong: git branch <name> && git reset --soft origin/$branch. Does not block."
  fk_warn "  (opt out: add 'default_branch_ok: true' to the '## preship config' block.)"
fi
exit 0
