#!/usr/bin/env bash
# flowkit gate: the repo's gates as ONE command, for every place git hooks do not
# run (Claude Code's /ship watch pushes with hooks off, CI, a GUI client).
# Standalone on purpose: CI checks this repo out and runs it without install.sh.
set -uo pipefail

usage() {
  cat <<'EOF'
usage: flowkit gate [--range <rev-range>] [--full] [--secrets-only] [repo-dir]

  Scans the commits in <rev-range> for secrets (gitleaks) and runs the lint and
  typecheck declared in the repo's '## preship config' block of CLAUDE.md.
  --range         commits to scan (default: <merge-base with the default branch>..HEAD)
  --full          also run build: and test:
  --secrets-only  skip the config commands (CI jobs without the toolchain)
Exit 0 = every gate green; 1 = a gate failed; 2 = usage error.
EOF
}

RANGE="" FULL=0 SECRETS_ONLY=0 TARGET="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --range) RANGE="${2:?--range needs a value}"; shift 2 ;;
    --full) FULL=1; shift ;;
    --secrets-only) SECRETS_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "x gate: unknown option $1" >&2; usage >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TARGET" || { echo "x gate: no such dir $TARGET" >&2; exit 2; }
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "x gate: not a git repo" >&2; exit 2; }
cd "$ROOT" || exit 2

default_range() {
  local def base
  def="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
  [[ -n "$def" ]] || for b in origin/main origin/master main master; do
    git rev-parse --verify --quiet "$b" >/dev/null && { def="$b"; break; }
  done
  [[ -n "$def" ]] || return 1
  base="$(git merge-base HEAD "$def" 2>/dev/null)" || return 1
  [[ "$base" == "$(git rev-parse HEAD)" ]] && return 1
  printf '%s..HEAD\n' "$(git rev-parse --short "$base")"
}

config_value() { # $1 = key; value from the preship config yaml fence, comment stripped
  # shellcheck disable=SC2016  # backtick fences are literal
  tr -d '\r' < CLAUDE.md 2>/dev/null \
    | sed -nE '/^## (pre)?ship config$/,/^## /p' \
    | sed -nE '/^```ya?ml$/,/^```$/p' \
    | sed -n "s/^$1:[[:space:]]*//p" | sed 's/[[:space:]]#.*$//; s/^#.*$//' | head -1
}

gitleaks_config() { # same precedence as the hooks: repo-local, then central
  if [[ -f .gitleaks.toml ]]; then echo ".gitleaks.toml"; return; fi
  local c
  c="$(find "$(git rev-parse --git-common-dir)/info/lefthook-remotes" \
    -path '*/hooks/.gitleaks.toml' 2>/dev/null | head -1)"
  [[ -n "$c" ]] || c="$SELF_DIR/../hooks/.gitleaks.toml"
  [[ -f "$c" ]] && echo "$c"
}

FAILED=0
report() { # $1 = ok|x|-, rest = message
  local mark="$1"; shift
  echo "$mark $*"
  [[ "$mark" == "x" ]] && FAILED=1
  return 0
}

if [[ -z "$RANGE" ]]; then
  RANGE="$(default_range)" || RANGE=""
fi
echo "-- flowkit gate ($(basename "$ROOT"))${RANGE:+ range $RANGE}"

if ! command -v gitleaks >/dev/null 2>&1; then
  report x "secrets: gitleaks not installed -- the scan did not run"
elif [[ -z "$RANGE" ]]; then
  report - "secrets: no commits ahead of the default branch -- nothing to scan"
else
  set -- git --redact --no-banner --verbose --log-opts="$RANGE"
  cfg="$(gitleaks_config)"
  [[ -n "$cfg" ]] && set -- "$@" --config "$cfg"
  [[ -f .gitleaks-baseline.json ]] && set -- "$@" --baseline-path .gitleaks-baseline.json
  if out="$(gitleaks "$@" 2>&1)"; then
    report ok "secrets: no leaks in $RANGE"
  else
    printf '%s\n' "$out" | grep -E '^(RuleID|File|Line|Commit):' | sed 's/^/    /' | head -20
    report x "secrets: leaks found in $RANGE (rotate, then rewrite or annotate)"
  fi
fi

run_key() { # $1 = config key
  local cmd
  cmd="$(config_value "$1")"
  if [[ -z "$cmd" ]]; then
    report - "$1: not declared in the preship config"
  elif ( eval "$cmd" ) > "${TMPDIR:-/tmp}/flowkit-gate-$1.log" 2>&1; then
    report ok "$1: $cmd"
  else
    tail -15 "${TMPDIR:-/tmp}/flowkit-gate-$1.log" | sed 's/^/    /'
    report x "$1: $cmd"
  fi
  rm -f "${TMPDIR:-/tmp}/flowkit-gate-$1.log"
}

if [[ "$SECRETS_ONLY" == 0 ]]; then
  if ! tr -d '\r' < CLAUDE.md 2>/dev/null | grep -qE '^## (pre)?ship config$'; then
    report - "config: no '## preship config' block in CLAUDE.md -- only the secret scan ran"
  else
    run_key lint
    run_key typecheck
    if [[ "$FULL" == 1 ]]; then
      run_key build
      run_key test
    fi
  fi
fi

if [[ "$FAILED" == 0 ]]; then echo "-- gate: PASS"; else echo "-- gate: FAIL"; fi
exit "$FAILED"
