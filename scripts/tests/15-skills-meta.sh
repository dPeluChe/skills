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

# reference routing: a dangling pointer and an orphan file are both reported
RF="$TMP/skills-meta/ref-skill"
mkdir -p "$RF/references"
printf -- '---\nname: ref-skill\ndescription: x\nallowed-tools: Read\n---\nLoad references/gone.md.\n' > "$RF/SKILL.md"
: > "$RF/references/orphan.md"
probs="$(skill_meta_problems "$RF")"
if grep -q 'gone.md, which does not exist' <<<"$probs" && grep -q 'orphan.md is not named' <<<"$probs"; then
  ok "skill meta: dangling and orphan references are reported"
else
  nope "skill meta: reference checks did not fire: $probs"
fi

# every skill has a behavior case and a negative-trigger case, and is in the suite-wide
# no-skill guard; social-posts is exempt
tags="$(grep -hE '^tags:' "$REPO_DIR"/evals/*/case.yaml 2>/dev/null)"
pos="$(grep -v negative <<<"$tags")"; neg="$(grep negative <<<"$tags")"
guard="$(cat "$REPO_DIR"/evals/no-skill-on-bugfix/graders/no-skill.md 2>/dev/null)"
tagged() { grep -qE "[[ ,]$2[],]" <<<"$1"; }
for d in "$REPO_DIR"/skills/*/; do
  s="$(basename "$d")"; [[ "$s" == social-posts ]] && continue
  if tagged "$pos" "$s"; then ok "skill evals: $s"; else nope "skill evals: $s has no behavior case tagged with its name"; fi
  if tagged "$neg" "$s"; then ok "skill evals: $s negative"; else nope "skill evals: $s has no negative case (tags: [$s, negative])"; fi
  if grep -qE "[:|]${s}[|)]" <<<"$guard"; then ok "skill evals: $s in no-skill guard"; else nope "skill evals: $s missing from evals/no-skill-on-bugfix/graders/no-skill.md"; fi
done
