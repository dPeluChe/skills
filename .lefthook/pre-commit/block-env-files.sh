#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# templates are committable (setup guides say cp .env.ejemplo .env); gitleaks
# still scans their content in the same commit
bad="$(git diff --cached --name-only --diff-filter=ACMR \
  | grep -E '(^|/)\.env(\..+)?$' | grep -Eiv "$FK_ENV_TEMPLATE_RE" || true)"
if [ -n "$bad" ]; then
  fk_warn "BLOCKED -- .env files staged (secrets never enter a commit):"
  echo "$bad" >&2
  fk_warn "unstage with: git restore --staged <file>"
  fk_warn "naming a TEMPLATE? .env.example/.ejemplo/.sample/.template/.dist are allowed"
  exit 1
fi
exit 0
