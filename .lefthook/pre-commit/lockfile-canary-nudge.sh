#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# a dependency bump can stop a whole extension from being linted with no code in
# the diff; the lockfile is what the code-scoped checks skip. Never blocks.
locks="$(git diff --cached --name-only --diff-filter=ACMR \
  | grep -E '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb|npm-shrinkwrap\.json)$' || true)"
if [ -n "$locks" ]; then
  fk_warn "lockfile changed -- a dependency bump can silently shift lint/typecheck coverage"
  fk_warn "  (e.g. an upgrade unscopes a preset and clobbers a parser -- a whole extension stops being linted)."
  fk_warn "  Verify the gate still catches: flowkit lint-health --canary. Does not block."
fi
exit 0
