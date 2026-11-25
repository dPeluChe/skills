#!/usr/bin/env bash
# shellcheck disable=SC2034  # most globals set here are consumed by the lib/ modules
# Entry point: parse mode/flags, source scripts/lib/*.sh, dispatch. Modes:
# docs/GUIDES/FLOWKIT.md (or `flowkit help`); module map: docs/ARCHITECTURE/FLOWKIT_INTERNALS.md
set -euo pipefail

resolve_self() { # portable readlink -f: follow symlinks to the real script path
  local src="$1" dir target
  while [[ -L "$src" ]]; do
    dir="$(cd "$(dirname "$src")" && pwd)"
    target="$(readlink "$src")"
    case "$target" in
      /*) src="$target" ;;
      *)  src="$dir/$target" ;;
    esac
  done
  dir="$(cd "$(dirname "$src")" && pwd)"
  printf '%s/%s\n' "$dir" "$(basename "$src")"
}

SELF="$(resolve_self "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SELF")"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

AGENTS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
BIN_DIR="${FLOWKIT_BIN_DIR:-$HOME/bin}"
HARNESS_LINK="${AGENTS_HOOKS_DIR:-$HOME/.agents/hooks-harness}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
MODE="sync"; COPY=0; PROBLEMS=0; TARGET_REPO=""; TEAM=0; INCLUDE_PARENT=0
VERIFY_ONLY=0; VERIFY_FAILED=0; LAST_VERIFY_RC=0; LINT_MEASURE=""; LINT_CANARY=0

case "${1:-}" in
  --check)   MODE="check"; shift ;;
  --prune)   MODE="prune"; shift ;;
  --copy)    COPY=1; shift ;;
  --upgrade) MODE="upgrade"; shift ;;
  --harness) MODE="harness"; shift ;;
  --about)   MODE="about"; shift ;;
  --lint-health)
    MODE="lint-health"; shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --measure) LINT_MEASURE="${2:?usage: install.sh --lint-health --measure '<rule>' [--list] [path]}"; shift 2 ;;
        --list) LINT_LIST=1; shift ;;
        --canary)  LINT_CANARY=1; shift ;;
        *) TARGET_REPO="$1"; shift ;;
      esac
    done
    ;;
  --loc-health)
    MODE="loc-health"; shift
    [[ $# -gt 0 ]] && { TARGET_REPO="$1"; shift; }
    ;;
  --repo)
    MODE="repo"; shift
    TARGET_REPO="${1:?usage: install.sh --repo <path> [--team] [--children-only|--include-parent]}"; shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --team)           TEAM=1; shift ;;
        --children-only)  INCLUDE_PARENT=0; shift ;;  # default; kept explicit
        --include-parent) INCLUDE_PARENT=1; shift ;;
        --verify)         VERIFY_ONLY=1; shift ;;
        *) echo "x unknown --repo option: $1" >&2; exit 1 ;;
      esac
    done
    ;;
  --ci)
    MODE="ci"; shift
    TARGET_REPO="${1:?usage: install.sh --ci <path>}"; shift
    ;;
  --unhook)
    MODE="unhook"; shift
    TARGET_REPO="${1:?usage: install.sh --unhook <path>}"; shift
    ;;
esac

for _mod in util chain repo-wire stamp stamp-shipconfig verify lifecycle lint-health lint-canary loc-health ci; do
  # shellcheck disable=SC1090  # module set is fixed; path resolved via resolve_self
  source "$SCRIPT_DIR/lib/$_mod.sh"
done

mkdir -p "$AGENTS_DIR" "$CLAUDE_DIR"

case "$MODE" in
  repo)    install_repo ;;
  unhook)  run_unhook ;;
  about)   run_about ;;
  harness) install_harness ;;
  ci)      run_ci_stamp "$TARGET_REPO" ;;
  upgrade) run_upgrade ;;
  lint-health)
    if [[ "$LINT_CANARY" -eq 1 ]]; then run_lint_canary "${TARGET_REPO:-.}"
    elif [[ -n "$LINT_MEASURE" ]]; then
      if [[ "${LINT_LIST:-0}" == 1 ]]; then run_lint_measure "$LINT_MEASURE" "${TARGET_REPO:-.}" --list
      else run_lint_measure "$LINT_MEASURE" "${TARGET_REPO:-.}"; fi
    else run_lint_health "${TARGET_REPO:-.}"; fi ;;
  loc-health) run_loc_health "${TARGET_REPO:-.}" ;;
  *)       run_sync "$@" ;;
esac
