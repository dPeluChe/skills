# shellcheck shell=bash
# shellcheck disable=SC2154  # REPO_DIR/TMP come from the runner
# ── skill metadata: the rules live in chain.sh (flowkit check runs them) ────
# shellcheck source=scripts/lib/chain.sh
source "$REPO_DIR/scripts/lib/chain.sh"

for d in "$REPO_DIR"/skills/*/; do
  probs="$(skill_meta_problems "$d")"
  if [[ -z "$probs" ]]; then
    ok "skill meta: $(basename "$d")"
  else
    nope "skill meta: $(basename "$d"): $(tr '\n' ';' <<<"$probs")"
  fi
done

# the rules fire: an overlong description, a wrong name and a missing allowed-tools
SM="$TMP/skills-meta/bad-skill"
mkdir -p "$SM"
{
  printf -- '---\nname: other-name\ndescription: >\n'
  for _ in $(seq 1 30); do printf '  forty characters of trigger text here.\n'; done
  printf -- '---\n\n# body\n'
} > "$SM/SKILL.md"
probs="$(skill_meta_problems "$SM")"
if grep -q 'chars > 1024' <<<"$probs" && grep -q 'name must match' <<<"$probs" \
   && grep -q 'no allowed-tools' <<<"$probs"; then
  ok "skill meta: a bad skill is reported (length, name, allowed-tools)"
else
  nope "skill meta: rules did not fire on the bad fixture: $probs"
fi
