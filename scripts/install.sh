#!/usr/bin/env bash
# Sync skills into the 2-hop chain used by this machine:
#   ~/.claude/skills/<name> -> ~/.agents/skills/<name> -> <repo>/skills/<name>
# (~/.agents/skills is the shared hub so every agent harness serves the same skills.)
#
# Usage:
#   ./scripts/install.sh              # sync ALL repo skills (create/fix missing links)
#   ./scripts/install.sh ship         # sync one skill
#   ./scripts/install.sh --check      # doctor mode: validate everything, change nothing (exit 0/1)
#   ./scripts/install.sh --prune      # sync + remove orphan links that point into this repo
#   ./scripts/install.sh --copy X     # legacy: copy instead of link (single hop, discouraged)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE="sync"; COPY=0; PROBLEMS=0

case "${1:-}" in
  --check) MODE="check"; shift ;;
  --prune) MODE="prune"; shift ;;
  --copy)  COPY=1; shift ;;
esac

mkdir -p "$AGENTS_DIR" "$CLAUDE_DIR"

note() { echo "$@"; }
bad()  { echo "✗ $*"; PROBLEMS=$((PROBLEMS + 1)); }

# ── one skill: ensure (or verify) both hops ────────────────────────────────
sync_one() {
  local name="$1" src="$REPO_DIR/skills/$1"
  local hop1="$AGENTS_DIR/$name" hop2="$CLAUDE_DIR/$name"
  [[ -d "$src" && -f "$src/SKILL.md" ]] || { bad "unknown skill or missing SKILL.md: $name"; return 0; }

  if [[ "$COPY" == 1 ]]; then
    rm -rf "$hop2"; cp -R "$src" "$hop2"; note "→ copied  $name (single hop, legacy)"; return 0
  fi

  # hop 1: ~/.agents/skills/<name> -> absolute repo path
  if [[ -L "$hop1" && "$(readlink "$hop1")" == "$src" ]]; then
    :
  elif [[ -e "$hop1" && ! -L "$hop1" ]]; then
    bad "$hop1 exists and is not a symlink — remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "$name: hop1 missing/wrong ($hop1)"; return 0; }
    rm -f "$hop1"; ln -s "$src" "$hop1"; note "→ hop1 linked  $name"
  fi

  # hop 2: ~/.claude/skills/<name> -> ../../.agents/skills/<name> (relative, matches existing style)
  local want2="../../.agents/skills/$name"
  if [[ -L "$hop2" && "$(readlink "$hop2")" == "$want2" ]]; then
    :
  elif [[ -e "$hop2" && ! -L "$hop2" ]]; then
    bad "$hop2 exists and is not a symlink — remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "$name: hop2 missing/wrong ($hop2)"; return 0; }
    rm -f "$hop2"; ln -s "$want2" "$hop2"; note "→ hop2 linked  $name"
  fi

  # end-to-end: the chain must resolve to a readable SKILL.md
  if [[ ! -f "$hop2/SKILL.md" ]]; then
    bad "$name: chain does not resolve to SKILL.md"
  elif [[ "$MODE" == "check" ]]; then
    note "✓ $name"
  fi
}

# ── orphans: dead links that were meant for this chain ─────────────────────
scan_orphans() {
  local dir="$1" link target raw
  for link in "$dir"/*; do
    [[ -L "$link" ]] || continue
    target="$(readlink -f "$link" 2>/dev/null || true)"
    if [[ -z "$target" || ! -e "$target" ]]; then
      raw="$(readlink "$link")"
      if [[ "$raw" == *"$REPO_DIR"* || "$raw" == *".agents/skills"* ]]; then
        if [[ "$MODE" == "prune" ]]; then
          rm -f "$link"; note "→ pruned orphan $link"
        else
          bad "orphan link: $link -> $raw"
        fi
      fi
    fi
  done
}

# ── main ───────────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
  for s in "$@"; do sync_one "$s"; done
else
  for d in "$REPO_DIR"/skills/*/; do sync_one "$(basename "$d")"; done
  scan_orphans "$AGENTS_DIR"
  scan_orphans "$CLAUDE_DIR"
fi

# repo hygiene: skills are served from the checked-out branch
BRANCH="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo '?')"
[[ "$BRANCH" != "main" ]] && bad "repo is on branch '$BRANCH' — symlinks serve it to ALL agents (checkout main)"

if [[ "$PROBLEMS" -gt 0 ]]; then
  echo "── $PROBLEMS problem(s) found"
  exit 1
fi
if [[ "$MODE" == "check" ]]; then echo "── chain healthy"; else echo "── in sync. Skills pick up on next session."; fi
