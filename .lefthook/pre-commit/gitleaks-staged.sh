#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# hard block on any staged leak
if ! command -v gitleaks >/dev/null 2>&1; then
  fk_warn "gitleaks not installed (brew install gitleaks) -- secret scan SKIPPED"
  exit 0
fi
set -- git --staged --redact
cfg="$(fk_gitleaks_cfg)"
[ -n "$cfg" ] && set -- "$@" --config "$cfg"
[ -f .gitleaks-baseline.json ] && set -- "$@" --baseline-path .gitleaks-baseline.json
exec gitleaks "$@"
