# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (REPO_DIR, MODE, COPY, ...) come from install.sh
# ── chain: skills symlink chain (sync/check/prune) + FLOW + flowkit link ───
# Sourced by scripts/install.sh (the entrypoint); never executed directly.

# ── skill metadata: what the harness reads before any body loads ───────────
skill_meta_problems() { # $1 = skill dir; prints one problem per line, nothing when clean
  local dir="$1" name fm desc
  name="$(basename "$dir")"
  fm="$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && /^---$/ { exit } NR > 1' "$dir/SKILL.md")"
  [[ -n "$fm" ]] || { echo "no frontmatter"; return 0; }
  # folded/literal block (description: > or |) or a one-line value, flattened
  desc="$(printf '%s\n' "$fm" | awk '
    /^description:/ { sub(/^description:[[:space:]]*[>|]?-?[[:space:]]*/, ""); d = $0; on = 1; next }
    on && /^[[:space:]]/ { d = d " " $0; next }
    { on = 0 }
    END { print d }' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
  grep -qx "name: $name" <<<"$fm" || echo "name must match the folder"
  if [[ -z "$desc" ]]; then echo "no description"
  elif (( ${#desc} > 1024 )); then echo "description ${#desc} chars > 1024 (the skill listing truncates it)"
  fi
  grep -q '^allowed-tools:' <<<"$fm" || echo "no allowed-tools"
  if grep -q $'\xe2\x80\x94' <<<"$fm"; then echo "em dash in frontmatter"; fi
}

# ── one skill: ensure (or verify) both hops ────────────────────────────────
sync_one() {
  local name="$1" src="$REPO_DIR/skills/$1"
  local hop1="$AGENTS_DIR/$name" hop2="$CLAUDE_DIR/$name"
  [[ -d "$src" && -f "$src/SKILL.md" ]] || { bad "unknown skill or missing SKILL.md: $name"; return 0; }
  local p
  while IFS= read -r p; do [[ -n "$p" ]] && bad "$name: $p"; done < <(skill_meta_problems "$src")

  if [[ "$COPY" == 1 ]]; then
    rm -rf "$hop2"; cp -R "$src" "$hop2"; note "-> copied  $name (single hop, legacy)"; return 0
  fi

  # hop 1: ~/.agents/skills/<name> -> absolute repo path
  if [[ -L "$hop1" && "$(readlink "$hop1")" == "$src" ]]; then
    :
  elif [[ -e "$hop1" && ! -L "$hop1" ]]; then
    bad "$hop1 exists and is not a symlink -- remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "$name: hop1 missing/wrong ($hop1)"; return 0; }
    rm -f "$hop1"; ln -s "$src" "$hop1"; note "-> hop1 linked  $name"
  fi

  # hop 2: ~/.claude/skills/<name> -> ../../.agents/skills/<name> (relative, matches existing style)
  local want2="../../.agents/skills/$name"
  if [[ -L "$hop2" && "$(readlink "$hop2")" == "$want2" ]]; then
    :
  elif [[ -e "$hop2" && ! -L "$hop2" ]]; then
    bad "$hop2 exists and is not a symlink -- remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "$name: hop2 missing/wrong ($hop2)"; return 0; }
    rm -f "$hop2"; ln -s "$want2" "$hop2"; note "-> hop2 linked  $name"
  fi

  # end-to-end: the chain must resolve to a readable SKILL.md
  if [[ ! -f "$hop2/SKILL.md" ]]; then
    bad "$name: chain does not resolve to SKILL.md"
  elif [[ "$MODE" == "check" ]]; then
    note "ok $name"
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
          rm -f "$link"; note "-> pruned orphan $link"
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
    bad "$link exists and is not a symlink -- remove it to adopt"
  else
    [[ "$MODE" == "check" ]] && { bad "FLOW_CLAUDE.md link missing ($link)"; return 0; }
    rm -f "$link"; ln -s "$src" "$link"; note "-> FLOW linked  FLOW_CLAUDE.md"
  fi
}

# ── flowkit CLI: global entry point served from ~/bin ──────────────────────
ensure_flowkit_link() {
  local src="$REPO_DIR/bin/flowkit" link="$BIN_DIR/flowkit"
  [[ -f "$src" ]] || { bad "bin/flowkit missing from repo"; return 0; }
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    :
  elif [[ -e "$link" && ! -L "$link" ]]; then
    bad "$link exists and is not a symlink -- remove it to adopt"
    return 0
  else
    [[ "$MODE" == "check" ]] && { bad "flowkit link missing/wrong ($link)"; return 0; }
    mkdir -p "$BIN_DIR"
    rm -f "$link"; ln -s "$src" "$link"; note "-> flowkit linked  $link"
  fi
  # Complete the job: append the export to the shell rc (idempotent,
  # marker-guarded). FLOWKIT_NO_RC=1 opts out and prints the line instead.
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
      local rc_file="$HOME/.zshrc" export_line
      [[ "${SHELL:-}" == *bash* ]] && rc_file="$HOME/.bashrc"
      if [[ "$BIN_DIR" == "$HOME/bin" ]]; then
        # shellcheck disable=SC2016  # the line is meant literally for the rc file
        export_line='export PATH="$HOME/bin:$PATH"'
      else
        export_line="export PATH=\"$BIN_DIR:\$PATH\""
      fi
      if [[ "${FLOWKIT_NO_RC:-}" == "1" ]]; then
        note "! $BIN_DIR is not in your PATH -- add this line to $rc_file:"
        note "  $export_line"
      elif grep -qF "# flowkit PATH" "$rc_file" 2>/dev/null; then
        note "! $BIN_DIR not in this shell's PATH yet -- restart the shell (rc already configured)"
      else
        printf '\n# flowkit PATH\n%s\n' "$export_line" >> "$rc_file"
        note "-> PATH export appended to $rc_file -- restart the shell (or: source $rc_file)"
      fi
      ;;
  esac
}

# ── sync/check/prune driver: the default mode of install.sh ───────────────
run_sync() { # $@ = specific skill names (default: all repo skills)
  [[ "$MODE" == "check" ]] && note "$(flowkit_version)"
  if [[ $# -gt 0 ]]; then
    for s in "$@"; do sync_one "$s"; done
  else
    for d in "$REPO_DIR"/skills/*/; do sync_one "$(basename "$d")"; done
    ensure_flow_link
    ensure_flowkit_link
    scan_orphans "$AGENTS_DIR"
    scan_orphans "$CLAUDE_DIR"
    [[ "$MODE" == "check" ]] && check_harness
  fi

  # repo hygiene: skills are served from the checked-out branch
  BRANCH="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo '?')"
  [[ "$BRANCH" != "main" ]] && bad "repo is on branch '$BRANCH' -- symlinks serve it to ALL agents (checkout main)"

  if [[ "$PROBLEMS" -gt 0 ]]; then
    problem_summary
    exit 1
  fi
  if [[ "$MODE" == "check" ]]; then echo "-- chain healthy"; else echo "-- in sync. Skills pick up on next session."; fi
}
