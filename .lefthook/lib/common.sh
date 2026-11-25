# shellcheck shell=sh
# The one copy of what the hooks, scripts/gate.sh, install.sh and secret-guard
# all need. POSIX sh (lefthook runs it); bash callers source it too.

# central config travels with this lib (same clone, two dirs up)
FK_LIB_DIR="${FK_LIB_DIR:-.}"
FK_CENTRAL_ROOT="$FK_LIB_DIR/../.."
# shellcheck disable=SC2034
FK_ENV_TEMPLATE_RE='\.env\.(example|ejemplo|sample|template|dist)$'
# shellcheck disable=SC2034  # consumed by the scripts that source this lib
# not code-to-split: lockfiles, minified, generated, maps, snapshots, docs, binaries
FK_LOC_SKIP='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|composer\.lock|poetry\.lock|Gemfile\.lock)$|\.min\.|\.map$|\.snap$|_generated|/generated/|\.d\.ts$|\.(md|mdx|markdown|rst|adoc)$|\.(svg|png|jpe?g|gif|webp|ico|pdf|woff2?|ttf|eot|mp4|mov|zip|gz|tgz|lock)$'

fk_warn() { printf '[hooks] %s\n' "$*" >&2; }

fk_root() { # [$1 = dir]
  git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${1:-.}"
}

fk_config_block() { # [$1 = dir]; yaml body of the '## (pre)ship config' fence in CLAUDE.md
  _f="$(fk_root "${1:-.}")/CLAUDE.md"
  [ -f "$_f" ] || return 0
  # shellcheck disable=SC2016  # backtick fences are literal
  tr -d '\r' < "$_f" | sed -nE '/^## (pre)?ship config$/,/^## /p' \
    | sed -nE '/^```ya?ml$/,/^```$/p' | sed '1d;$d'
}

fk_yaml_get() { # $1 = key; reads a config block on stdin, trailing ' # comment' stripped
  sed -n "s/^$1:[[:space:]]*//p" | sed 's/[[:space:]]#.*$//; s/^#.*$//; s/[[:space:]]*$//' | head -1
}

fk_config_get() { # $1 = key [$2 = dir]
  fk_config_block "${2:-.}" | fk_yaml_get "$1"
}

fk_gitleaks_cfg() { # [$1 = dir]; repo-local .gitleaks.toml wins over the central one
  if [ -f "${1:-.}/.gitleaks.toml" ]; then echo "${1:-.}/.gitleaks.toml"
  elif [ -f "$FK_CENTRAL_ROOT/hooks/.gitleaks.toml" ]; then echo "$FK_CENTRAL_ROOT/hooks/.gitleaks.toml"
  fi
}

fk_gitleaks() { # gitleaks <args> + the effective config and baseline of the repo in cwd
  _c="$(fk_gitleaks_cfg)"
  [ -n "$_c" ] && set -- "$@" --config "$_c"
  [ -f .gitleaks-baseline.json ] && set -- "$@" --baseline-path .gitleaks-baseline.json
  gitleaks "$@"
}

fk_default_branch() { # prints the default branch ref (origin/main, main...), or nothing
  git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null && return 0
  for _b in origin/main origin/master main master; do
    git rev-parse --verify --quiet "$_b" >/dev/null && { echo "$_b"; return 0; }
  done
  return 1
}
