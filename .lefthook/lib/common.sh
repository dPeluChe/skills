# shellcheck shell=sh
# Shared by every hook script and scripts/gate.sh: ONE parser for the preship
# config and ONE gitleaks-config lookup. Callers set FK_LIB_DIR before sourcing.

# central config travels with these scripts (same remote clone, two dirs up)
FK_CENTRAL_ROOT="${FK_LIB_DIR:-.}/../.."

fk_warn() { printf '[hooks] %s\n' "$*" >&2; }

fk_root() { git rev-parse --show-toplevel 2>/dev/null || echo .; }

fk_config_block() { # yaml body of the '## (pre)ship config' fence in CLAUDE.md
  _f="$(fk_root)/CLAUDE.md"
  [ -f "$_f" ] || return 0
  # shellcheck disable=SC2016  # backtick fences are literal
  tr -d '\r' < "$_f" | sed -nE '/^## (pre)?ship config$/,/^## /p' \
    | sed -nE '/^```ya?ml$/,/^```$/p' | sed '1d;$d'
}

fk_config_get() { # $1 = key; value with a trailing ' # comment' stripped
  fk_config_block | sed -n "s/^$1:[[:space:]]*//p" \
    | sed 's/[[:space:]]#.*$//; s/^#.*$//; s/[[:space:]]*$//' | head -1
}

fk_gitleaks_cfg() { # repo-local .gitleaks.toml wins over the central one
  if [ -f .gitleaks.toml ]; then echo ".gitleaks.toml"
  elif [ -f "$FK_CENTRAL_ROOT/hooks/.gitleaks.toml" ]; then echo "$FK_CENTRAL_ROOT/hooks/.gitleaks.toml"
  fi
}
