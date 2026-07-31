#!/usr/bin/env bash
# shellcheck disable=SC2034  # most globals set here are consumed by the lib/ modules
# Entry point for the skills + hooks + flow layer. Thin by design: parse the
# mode/flags, source the domain modules from scripts/lib/, dispatch. ALL the
# logic lives in the modules:
#   lib/util.sh       output helpers, versions, constants, shared git plumbing
#   lib/chain.sh      skills symlink chain (sync/check/prune) + FLOW + flowkit link
#   lib/repo-wire.sh  --repo: wire centralized git hooks into target repos
#   lib/stamp.sh      per-repo stamps: gitleaks baseline, FLOW import, ship config
#   lib/verify.sh     --repo --verify: effective hook state + canary probe
#   lib/lifecycle.sh  --unhook, --about, --harness, --upgrade
#
# Skills chain synced here:
#   ~/.claude/skills/<name> -> ~/.agents/skills/<name> -> <repo>/skills/<name>
# (~/.agents/skills is the shared hub so every agent harness serves the same skills.)
#
# Usage:
#   ./scripts/install.sh              # sync ALL repo skills (create/fix missing links)
#   ./scripts/install.sh ship         # sync one skill
#   ./scripts/install.sh --check      # doctor mode: validate everything, change nothing (exit 0/1)
#   ./scripts/install.sh --prune      # sync + remove orphan links that point into this repo
#   ./scripts/install.sh --copy X     # legacy: copy instead of link (single hop, discouraged)
#   ./scripts/install.sh --repo <path> [--team] [--children-only|--include-parent]
#                                     # phase 2: wire centralized git hooks (lefthook
#                                     # remotes + gitleaks baseline + FLOW_CLAUDE.md
#                                     # import) into a target repo. A WORKSPACE (git
#                                     # repo whose 1st-level children are git repos)
#                                     # gets each child wired; the parent is skipped
#                                     # unless --include-parent.
#   ./scripts/install.sh --repo <path> --verify
#                                     # verify the EFFECTIVE hook state of <path>:
#                                     # config + effective hooksPath invokes lefthook
#                                     # + merged jobs + gitleaks + canary -- exit 0/1
#   ./scripts/install.sh --unhook <path>
#                                     # clean removal from <path>: lefthook stubs, OUR
#                                     # config files and OUR .git/info/exclude entries
#   ./scripts/install.sh --upgrade    # report lefthook/gitleaks versions vs minimums
#                                     # (+ brew outdated) and this clone vs origin/main
#   ./scripts/install.sh --about      # orientation for agents landing cold (exit 0)
#   ./scripts/install.sh --harness    # wire the Claude Code harness hooks (PreToolUse
#                                     # git-guard + secret-guard) into ~/.claude/settings.json
#
# Sync mode also links ~/bin/flowkit -> bin/flowkit (the CLI front-end that
# dispatches every subcommand back to this script); --check validates that link.
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
VERIFY_ONLY=0; VERIFY_FAILED=0; LAST_VERIFY_RC=0

case "${1:-}" in
  --check)   MODE="check"; shift ;;
  --prune)   MODE="prune"; shift ;;
  --copy)    COPY=1; shift ;;
  --upgrade) MODE="upgrade"; shift ;;
  --harness) MODE="harness"; shift ;;
  --about)   MODE="about"; shift ;;
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
  --unhook)
    MODE="unhook"; shift
    TARGET_REPO="${1:?usage: install.sh --unhook <path>}"; shift
    ;;
esac

for _mod in util chain repo-wire stamp stamp-shipconfig verify lifecycle; do
  # shellcheck disable=SC1090  # module set is fixed; path resolved via resolve_self
  source "$SCRIPT_DIR/lib/$_mod.sh"
done

mkdir -p "$AGENTS_DIR" "$CLAUDE_DIR"

case "$MODE" in
  repo)    install_repo ;;
  unhook)  run_unhook ;;
  about)   run_about ;;
  harness) install_harness ;;
  upgrade) run_upgrade ;;
  *)       run_sync "$@" ;;
esac
