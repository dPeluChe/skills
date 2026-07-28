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
#   ./scripts/install.sh --repo <path> [--team]
#                                     # phase 2: wire centralized git hooks
#                                     # (lefthook remotes + gitleaks baseline +
#                                     # FLOW_CLAUDE.md import) into a target repo
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE="sync"; COPY=0; PROBLEMS=0; TARGET_REPO=""; TEAM=0

case "${1:-}" in
  --check) MODE="check"; shift ;;
  --prune) MODE="prune"; shift ;;
  --copy)  COPY=1; shift ;;
  --repo)
    MODE="repo"; shift
    TARGET_REPO="${1:?usage: install.sh --repo <path> [--team]}"; shift
    [[ "${1:-}" == "--team" ]] && { TEAM=1; shift; }
    ;;
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

# ── FLOW_CLAUDE.md: served through the same ~/.agents hub as the skills ────
ensure_flow_link() {
  local src="$REPO_DIR/FLOW_CLAUDE.md" link="$AGENTS_DIR/FLOW_CLAUDE.md"
  [[ -f "$src" ]] || { bad "FLOW_CLAUDE.md missing from repo root"; return 0; }
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    :
  elif [[ -e "$link" && ! -L "$link" ]]; then
    bad "$link exists and is not a symlink — remove it to adopt"
  else
    [[ "$MODE" == "check" ]] && { bad "FLOW_CLAUDE.md link missing ($link)"; return 0; }
    rm -f "$link"; ln -s "$src" "$link"; note "→ FLOW linked  FLOW_CLAUDE.md"
  fi
}

# ── phase 2: centralized git hooks into a target repo (--repo <path>) ──────
REMOTE_URL="https://github.com/dPeluChe/skills"

die() { echo "✗ $*" >&2; exit 1; }

# ver_ge <have> <need> — numeric dotted-version compare
ver_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" == "$2" ]]
}

check_tool_versions() {
  local v missing=0
  if command -v lefthook >/dev/null 2>&1; then
    v="$(lefthook version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1)"
    ver_ge "${v:-0}" "1.10" || { echo "✗ lefthook >= 1.10 required (found ${v:-?})"; missing=1; }
  else
    echo "✗ lefthook not found — install it: brew install lefthook"; missing=1
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    v="$(gitleaks version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1)"
    ver_ge "${v:-0}" "8.19" || { echo "✗ gitleaks >= 8.19 required for 'gitleaks git' (found ${v:-?})"; missing=1; }
  else
    echo "✗ gitleaks not found — install it: brew install gitleaks"; missing=1
  fi
  [[ "$missing" == 0 ]] || die "missing/outdated tools — install them and re-run"
}

write_remotes_config() { # $1 = destination yml path
  cat > "$1" <<EOF
# Managed by dPeluChe/skills scripts/install.sh --repo.
# Central hooks live in that repo (hooks/lefthook-base.yml); lefthook
# refetches them at most once a day.
remotes:
  - git_url: $REMOTE_URL
    ref: main
    refetch_frequency: 24h
    configs:
      - hooks/lefthook-base.yml
EOF
  note "→ wrote $(basename "$1")"
}

ensure_global_gitignore() { # team mode: lefthook-local.yml must be globally ignored
  local gi
  gi="$(git config --global core.excludesFile 2>/dev/null || true)"
  gi="${gi/#\~/$HOME}"
  [[ -n "$gi" ]] || gi="$HOME/.config/git/ignore"
  if [[ -f "$gi" ]] && grep -qxF "lefthook-local.yml" "$gi"; then
    note "→ global gitignore already covers lefthook-local.yml ($gi)"
  else
    mkdir -p "$(dirname "$gi")"
    printf 'lefthook-local.yml\n' >> "$gi"
    [[ -n "$(git config --global core.excludesFile 2>/dev/null || true)" ]] \
      || git config --global core.excludesFile "$gi"
    note "→ added lefthook-local.yml to global gitignore ($gi)"
  fi
}

chain_husky() { # $1 = target repo; append lefthook to husky hooks, never replace
  local target="$1" hook file
  note "→ husky detected — chaining lefthook after it (not replacing)"
  for hook in pre-commit pre-push; do
    file="$target/.husky/$hook"
    if [[ -f "$file" ]] && grep -q "lefthook run $hook" "$file"; then
      continue
    fi
    printf 'lefthook run %s "$@"\n' "$hook" >> "$file"
    chmod +x "$file"
    note "→ chained lefthook into .husky/$hook"
  done
  echo "  NOTE: hooks stay husky-managed; lefthook runs as the last step of each."
}

run_gitleaks_baseline() { # $1 = target repo
  local target="$1" scan="git" n
  local report="$target/.gitleaks-baseline.json"
  gitleaks git --help >/dev/null 2>&1 || scan="detect"
  note "→ building gitleaks baseline (full history scan, one-time)…"
  ( cd "$target" && gitleaks "$scan" --config "$REPO_DIR/hooks/.gitleaks.toml" \
      --report-path "$report" --report-format json --redact \
      --exit-code 0 >/dev/null 2>&1 ) || true
  if [[ ! -f "$report" ]]; then
    bad "gitleaks baseline scan produced no report — run it manually"
    return 0
  fi
  n="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$report" 2>/dev/null \
    || grep -c '"RuleID"' "$report" || echo "?")"
  echo "  baseline: $n hallazgos — revísalos una vez"
  if [[ "$n" != "0" && "$n" != "?" ]]; then
    echo "  ┌─ file · rule ─────────────────────────────"
    python3 - "$report" 2>/dev/null <<'PY' || true
import json, sys
for f in json.load(open(sys.argv[1]))[:20]:
    print(f"  | {f.get('File', '?')} · {f.get('RuleID', '?')}")
PY
    echo "  └───────────────────────────────────────────"
    echo "  These findings are grandfathered by the baseline; NEW leaks still block."
  else
    echo "  (0 findings — clean history, baseline kept as an empty ledger)"
  fi
}

ensure_flow_import() { # $1 = target repo: @import FLOW into its CLAUDE.md
  local target="$1" cmd="$1/CLAUDE.md" line='@~/.agents/skills/FLOW_CLAUDE.md'
  ensure_flow_link
  [[ -f "$cmd" ]] || { printf '# CLAUDE.md\n' > "$cmd"; note "→ created CLAUDE.md"; }
  if grep -qF "$line" "$cmd"; then
    note "→ CLAUDE.md already imports FLOW_CLAUDE.md"
  else
    printf '\n%s\n' "$line" >> "$cmd"
    note "→ added FLOW_CLAUDE.md import to CLAUDE.md"
  fi
}

ensure_ship_config_template() { # $1 = target repo: stamp the block if missing
  local cmd="$1/CLAUDE.md"
  if grep -q '^## ship config' "$cmd" 2>/dev/null; then
    note "→ CLAUDE.md already has a '## ship config' block"
    return 0
  fi
  cat >> "$cmd" <<'EOF'

## ship config

```yaml
lint:            # TODO e.g. npm run lint
typecheck:       # TODO e.g. npx tsc --noEmit
build:           # TODO e.g. npm run build
test:            # TODO omit if none
merge_policy: ask   # auto | ask
loc_limit: 500
simplify: 500       # run /simplify only if changed LOC > N (off = only on request)
```
EOF
  note "→ stamped '## ship config' template in CLAUDE.md (fill the TODOs)"
}

install_repo() {
  local target team="$TEAM" cfg_file answer
  target="$(cd "$TARGET_REPO" 2>/dev/null && pwd)" || die "not a directory: $TARGET_REPO"
  git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $target"

  check_tool_versions

  # solo vs team: flag wins; otherwise ask (non-interactive defaults to solo)
  if [[ "$team" == 0 && -t 0 ]]; then
    read -r -p "Does this repo have a team (shared lefthook.yml)? [y/N] " answer
    [[ "$answer" == [yY]* ]] && team=1
  fi

  if [[ "$team" == 1 ]]; then
    cfg_file="$target/lefthook-local.yml"
    ensure_global_gitignore
  else
    cfg_file="$target/lefthook.yml"
  fi
  if [[ -f "$cfg_file" ]] && ! grep -qF "$REMOTE_URL" "$cfg_file"; then
    bad "$(basename "$cfg_file") exists and does not reference $REMOTE_URL — merge this snippet manually:"
    echo "  remotes:"
    echo "    - git_url: $REMOTE_URL"
    echo "      ref: main"
    echo "      refetch_frequency: 24h"
    echo "      configs: [hooks/lefthook-base.yml]"
  else
    write_remotes_config "$cfg_file"
  fi

  if [[ -d "$target/.husky" ]]; then
    chain_husky "$target"
  elif ( cd "$target" && lefthook install ); then
    note "→ lefthook install done"
  else
    bad "lefthook install failed — see its message above (e.g. a custom core.hooksPath); fix and re-run"
  fi

  run_gitleaks_baseline "$target"
  ensure_flow_import "$target"
  ensure_ship_config_template "$target"

  if [[ "$PROBLEMS" -gt 0 ]]; then
    echo "── $PROBLEMS problem(s) found"
    exit 1
  fi
  echo "── hooks wired into $target. First commit exercises them."
  exit 0
}

if [[ "$MODE" == "repo" ]]; then install_repo; fi

# ── main ───────────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
  for s in "$@"; do sync_one "$s"; done
else
  for d in "$REPO_DIR"/skills/*/; do sync_one "$(basename "$d")"; done
  ensure_flow_link
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
