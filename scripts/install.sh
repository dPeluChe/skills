#!/usr/bin/env bash
# Install skills into ~/.claude/skills (symlink by default, --copy to copy).
# Usage:
#   ./scripts/install.sh              # all skills, symlinked
#   ./scripts/install.sh doctos       # one skill
#   ./scripts/install.sh --copy pm-tasks
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE="link"

[[ "${1:-}" == "--copy" ]] && { MODE="copy"; shift; }

mkdir -p "$TARGET"

install_one() {
  local name="$1" src="$REPO_DIR/skills/$1" dst="$TARGET/$1"
  [[ -d "$src" ]] || { echo "✗ unknown skill: $name"; return 1; }
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "⚠ $dst exists and is not a symlink — skipping (remove it first to adopt)"
    return 0
  fi
  rm -f "$dst"
  if [[ "$MODE" == "link" ]]; then
    ln -s "$src" "$dst" && echo "→ linked  $name"
  else
    cp -R "$src" "$dst" && echo "→ copied  $name"
  fi
}

if [[ $# -gt 0 ]]; then
  for s in "$@"; do install_one "$s"; done
else
  for d in "$REPO_DIR"/skills/*/; do install_one "$(basename "$d")"; done
fi

echo "Done. Skills in $TARGET pick up on next Claude Code session."
