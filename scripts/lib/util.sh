# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034  # globals come from install.sh; constants are consumed by sibling modules
# ── util: output helpers, versions, constants, shared git plumbing ─────────
# Sourced by scripts/install.sh (the entrypoint); never executed directly.

note() { echo "$@"; }
bad()  { echo "x $*"; PROBLEMS=$((PROBLEMS + 1)); }

flowkit_version() { # prints "flowkit <VERSION> (<short sha>)"
  local v sha
  v="$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo 0.0.0)"
  sha="$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf 'flowkit %s (%s)\n' "$v" "$sha"
}

REMOTE_URL="https://github.com/dPeluChe/skills"
MIN_LEFTHOOK="1.10"
MIN_GITLEAKS="8.19"   # 'gitleaks git' needs it

die() { echo "x $*" >&2; exit 1; }

# Actionable follow-ups collected while wiring one repo; printed at the end of
# that repo's section as a copy-paste block for the human's agent.
AGENT_ACTIONS=""
agent_action() { AGENT_ACTIONS="${AGENT_ACTIONS}$*"$'\n'; }
print_agent_actions() {
  [[ -n "$AGENT_ACTIONS" ]] || return 0
  echo ""
  echo "---- copy below to your agent ----"
  printf '%s' "$AGENT_ACTIONS"
  echo "For context on this tooling run \`flowkit about\` -- if flowkit is not on PATH, read \`lefthook.yml\` + the \`## ship config\` block in CLAUDE.md + hooks/lefthook-base.yml in the skills repo."
  echo "---- end ----"
}

# ver_ge <have> <need> — numeric dotted-version compare
ver_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" == "$2" ]]
}

tool_version() { # $1 = tool; prints its dotted version (empty if unknown)
  "$1" version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -1
}

effective_hooks_dir() { # $1 = target repo; ABSOLUTE dir git actually consults
  # for hooks: core.hooksPath (local wins over global) or .git/hooks.
  local target="$1" hp
  hp="$(git -C "$target" config core.hooksPath 2>/dev/null || true)"
  if [[ -z "$hp" ]]; then
    printf '%s/hooks\n' "$(git -C "$target" rev-parse --absolute-git-dir)"
    return 0
  fi
  hp="${hp/#\~/$HOME}"
  case "$hp" in
    /*) printf '%s\n' "$hp" ;;
    *)  printf '%s/%s\n' "$target" "$hp" ;;
  esac
}

exclude_add() { # $1 = target repo, $2 = exact line for .git/info/exclude
  local ex
  ex="$(git -C "$1" rev-parse --absolute-git-dir)/info/exclude"
  mkdir -p "$(dirname "$ex")"
  grep -qxF "$2" "$ex" 2>/dev/null || printf '%s\n' "$2" >> "$ex"
}

exclude_remove() { # $1 = target repo, $2 = exact line; 0 only if it was removed
  local ex tmp
  ex="$(git -C "$1" rev-parse --absolute-git-dir)/info/exclude"
  { [[ -f "$ex" ]] && grep -qxF "$2" "$ex"; } || return 1
  tmp="$(mktemp)"
  grep -vxF "$2" "$ex" > "$tmp" || true
  mv "$tmp" "$ex"
}
