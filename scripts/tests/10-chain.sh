# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL come from 00-helpers.sh via the runner
# ── chain: sync mode links skills + FLOW + flowkit into an isolated home ────
# The 2-hop chain (~/.claude/skills -> ~/.agents/skills -> repo) is recreated
# under $TMP so hop2's relative target (../../.agents/skills/<name>) resolves.
# Exit codes are NOT asserted here: sync/check flag non-main branches by design.

CH="$TMP/chain-home"
mkdir -p "$CH/.agents/skills" "$CH/.claude/skills" "$CH/bin"

run_chain_install() { # $@ = install.sh args — fully isolated env, no rc writes
  AGENTS_SKILLS_DIR="$CH/.agents/skills" CLAUDE_SKILLS_DIR="$CH/.claude/skills" \
    FLOWKIT_BIN_DIR="$CH/bin" FLOWKIT_NO_RC=1 \
    CLAUDE_SETTINGS_FILE="$CH/settings.json" AGENTS_HOOKS_DIR="$CH/hooks-harness" \
    bash "$INSTALL" "$@" > "$TMP/out.log" 2> "$TMP/err.log" < /dev/null
}

run_chain_install || true
chain_n=0; chain_bad=0
for d in "$REPO_DIR"/skills/*/; do
  chain_name="$(basename "$d")"
  chain_n=$((chain_n + 1))
  if [[ ! -f "$CH/.claude/skills/$chain_name/SKILL.md" ]]; then
    nope "chain: $chain_name does not resolve to SKILL.md through hop1+hop2"
    chain_bad=1
  fi
done
[[ "$chain_bad" -eq 0 ]] && ok "chain: all $chain_n skills resolve through hop1+hop2 to SKILL.md"

if [[ "$(readlink "$CH/.agents/skills/FLOW_CLAUDE.md" 2>/dev/null)" == "$REPO_DIR/FLOW_CLAUDE.md" ]]; then
  ok "chain: FLOW_CLAUDE.md linked into the agents hub"
else
  nope "chain: FLOW_CLAUDE.md link missing or wrong in $CH/.agents/skills"
fi

if [[ "$(readlink "$CH/bin/flowkit" 2>/dev/null)" == "$REPO_DIR/bin/flowkit" ]] \
   && "$CH/bin/flowkit" help >/dev/null 2>&1; then
  ok "chain: ~/bin-style flowkit link created and runnable through the link"
else
  nope "chain: flowkit link missing/wrong or not runnable ($CH/bin/flowkit)"
fi

if grep -q "add this line to" "$TMP/out.log"; then
  ok "chain: FLOWKIT_NO_RC=1 prints the PATH export line instead of editing the rc"
else
  nope "chain: expected the PATH export note under FLOWKIT_NO_RC=1 (see $TMP/out.log)"
fi

run_chain_install --check || true
chain_bad=0
for d in "$REPO_DIR"/skills/*/; do
  chain_name="$(basename "$d")"
  grep -qx "ok $chain_name" "$TMP/out.log" || { nope "chain check: no 'ok $chain_name' line"; chain_bad=1; }
done
[[ "$chain_bad" -eq 0 ]] && ok "chain check: doctor reports 'ok <skill>' for all $chain_n skills"

ln -s "$REPO_DIR/skills/definitely-gone" "$CH/.agents/skills/definitely-gone"
run_chain_install --prune || true
if [[ ! -L "$CH/.agents/skills/definitely-gone" ]] && grep -q "pruned orphan" "$TMP/out.log"; then
  ok "chain prune: dangling repo-pointing link removed and reported"
else
  nope "chain prune: orphan link survived or not reported (see $TMP/out.log)"
fi
