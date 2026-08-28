# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/BASE_YML come from 00-helpers.sh via the runner
# ── lint-health pre-commit hook: diff-scoped advisory ──
# The (d) job in hooks/lefthook-base.yml alerts when THIS commit's staged diff
# WEAKENS lint (a blanket eslint-disable, or a rule turned off in an eslint
# config). Diff-scoped sibling of `flowkit lint-health`. ADVISORY: exit 0 always.
# Field origin: tennispro "turn no-unused-vars on repo-wide" + newbase/polizahoy
# scaffold with 6 rules off — the alert must fire the moment such a change is
# STAGED, not weeks later in a repo audit.

# Locate the effective hook block (extracted by 20-lefthook-blocks.sh into $TMP).
LH_HOOK="$(grep -l 'lint-health: this commit changes' "$TMP"/block*.sh 2>/dev/null | head -1)"
if [[ -n "$LH_HOOK" ]]; then
  ok "hook: lint-health-staged block present in lefthook-base.yml pre-commit"
else
  nope "hook: lint-health-staged block missing from lefthook-base.yml"
  return 0
fi

# fixture repo with one clean baseline commit; leaves changes staged for the run
lhh_repo() { # $1 = dir
  make_repo "$1"
  mkdir -p "$1/src"
  printf 'export default []\n' > "$1/eslint.config.js"
  printf 'export const a = 1\n' > "$1/src/a.ts"
  git -C "$1" add -A
  git -C "$1" -c user.email=t@t.t -c user.name=t commit -q -m base
}

# ── (1) blanket disable staged -> flagged with file, ADVISORY exit 0 ──────────
LHH1="$TMP/lhh-blanket"
lhh_repo "$LHH1"
printf '/* eslint-disable */\nexport const b = 2\n' > "$LHH1/src/b.ts"
# a GOOD scoped reasoned disable in the SAME commit must stay silent
printf '// eslint-disable-next-line no-console -- vendor blob\nconsole.log(1)\n' > "$LHH1/src/c.ts"
git -C "$LHH1" add -A
( cd "$LHH1" && sh "$LH_HOOK" ) > "$TMP/lhh1.log" 2>&1; lhh1_rc=$?
if [[ "$lhh1_rc" -eq 0 ]] \
   && grep -q "BLANKET disable(s) added" "$TMP/lhh1.log" \
   && grep -q "src/b.ts: /\* eslint-disable \*/" "$TMP/lhh1.log" \
   && ! grep -q "src/c.ts" "$TMP/lhh1.log"; then
  ok "hook blanket: staged /* eslint-disable */ flagged (file), scoped-reasoned silent, exit 0"
else
  nope "hook blanket: expected b.ts flagged + c.ts ignored + exit 0 (see $TMP/lhh1.log)"
fi

# ── (2) rule turned off in config staged -> flagged ──────────────────────────
LHH2="$TMP/lhh-off"
lhh_repo "$LHH2"
printf 'export default [{ rules: { "no-unused-vars": "off" } }]\n' > "$LHH2/eslint.config.js"
git -C "$LHH2" add -A
( cd "$LHH2" && sh "$LH_HOOK" ) > "$TMP/lhh2.log" 2>&1; lhh2_rc=$?
if [[ "$lhh2_rc" -eq 0 ]] \
   && grep -q "rule(s) turned OFF in an eslint config" "$TMP/lhh2.log" \
   && grep -q 'eslint.config.js:.*no-unused-vars.*off' "$TMP/lhh2.log"; then
  ok "hook off-rule: staged config change to \"off\" flagged, exit 0"
else
  nope "hook off-rule: config off-rule not flagged (see $TMP/lhh2.log)"
fi

# ── (3) off-rule detection is CONFIG-SCOPED: a source file with an "off" string
# literal must NOT false-positive as a turned-off rule ────────────────────────
LHH3="$TMP/lhh-srcoff"
lhh_repo "$LHH3"
printf 'export const mode = { debug: "off" }\n' > "$LHH3/src/opts.ts"
git -C "$LHH3" add -A
( cd "$LHH3" && sh "$LH_HOOK" ) > "$TMP/lhh3.log" 2>&1
if [[ ! -s "$TMP/lhh3.log" ]] || ! grep -q "turned OFF" "$TMP/lhh3.log"; then
  ok "hook scope: an \"off\" string in SOURCE (not a config) does not false-alert"
else
  nope "hook scope: source \"off\" literal wrongly flagged as off-rule (see $TMP/lhh3.log)"
fi

# ── (4) clean commit (only a reasoned scoped disable + a .md) -> SILENT ───────
LHH4="$TMP/lhh-clean"
lhh_repo "$LHH4"
printf '// eslint-disable-next-line no-console -- vendor blob\nconsole.log(1)\n' > "$LHH4/src/ok.ts"
printf '# notes\n' > "$LHH4/README.md"
git -C "$LHH4" add -A
( cd "$LHH4" && sh "$LH_HOOK" ) > "$TMP/lhh4.log" 2>&1; lhh4_rc=$?
if [[ "$lhh4_rc" -eq 0 && ! -s "$TMP/lhh4.log" ]]; then
  ok "hook clean: reasoned-scoped-only + docs commit stays silent (exit 0)"
else
  nope "hook clean: a non-weakening commit must produce no alert (see $TMP/lhh4.log)"
fi

# ── (5) non-JS-only staged change -> SILENT (no JS/TS touched) ────────────────
LHH5="$TMP/lhh-nonjs"
lhh_repo "$LHH5"
printf 'body { color: red }\n' > "$LHH5/style.css"
git -C "$LHH5" add -A
( cd "$LHH5" && sh "$LH_HOOK" ) > "$TMP/lhh5.log" 2>&1; lhh5_rc=$?
if [[ "$lhh5_rc" -eq 0 && ! -s "$TMP/lhh5.log" ]]; then
  ok "hook non-js: a CSS-only staged change is silent (nothing lint-relevant)"
else
  nope "hook non-js: non-JS change should be silent (see $TMP/lhh5.log)"
fi

# ── lockfile nudge: a dep bump (lockfile-only diff) can silently shift lint
# coverage -- the file the code-scoped checks skip. Staging a lockfile nudges to
# run --canary; a non-lockfile change stays silent. Field feedback.
LOCK_HOOK="$(grep -l 'lockfile changed' "$TMP"/block*.sh 2>/dev/null | head -1)"
if [[ -n "$LOCK_HOOK" ]]; then
  ok "hook: lockfile-canary-nudge block present in lefthook-base.yml pre-commit"
else
  nope "hook: lockfile-canary-nudge block missing"
  return 0
fi
LHLOCK="$TMP/lh-lockfile"
make_repo "$LHLOCK"
git -C "$LHLOCK" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m base
printf '{}\n' > "$LHLOCK/package-lock.json"; git -C "$LHLOCK" add package-lock.json
( cd "$LHLOCK" && sh "$LOCK_HOOK" ) > "$TMP/lhlock-a.log" 2>&1; a_rc=$?
printf 'body{}\n' > "$LHLOCK/x.css"; git -C "$LHLOCK" add x.css
git -C "$LHLOCK" -c user.email=t@t.t -c user.name=t commit -q -m lock 2>/dev/null
printf 'p{}\n' > "$LHLOCK/y.css"; git -C "$LHLOCK" add y.css
( cd "$LHLOCK" && sh "$LOCK_HOOK" ) > "$TMP/lhlock-b.log" 2>&1
if [[ "$a_rc" -eq 0 ]] \
   && grep -q "lockfile changed" "$TMP/lhlock-a.log" \
   && grep -q "flowkit lint-health --canary" "$TMP/lhlock-a.log" \
   && [[ ! -s "$TMP/lhlock-b.log" ]]; then
  ok "hook lockfile: staged lockfile nudges --canary (exit 0); non-lockfile change silent"
else
  nope "hook lockfile: nudge on lockfile / silence otherwise wrong (see $TMP/lhlock-a.log / b)"
fi

# ── default-branch nudge: committing to the default branch warns (never blocks);
# a feature branch is silent; `default_branch_ok: true` opts out. Field feedback:
# an agent committed to main twice and no hook chirped.
DB_HOOK="$(grep -l 'the default branch' "$TMP"/block*.sh 2>/dev/null | head -1)"
if [[ -n "$DB_HOOK" ]]; then
  ok "hook: default-branch-nudge block present in lefthook-base.yml pre-commit"
else
  nope "hook: default-branch-nudge block missing"
  return 0
fi
DBREPO="$TMP/db-nudge"
mkdir -p "$DBREPO"; git -C "$DBREPO" init -q -b main
git -C "$DBREPO" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m init
( cd "$DBREPO" && sh "$DB_HOOK" ) > "$TMP/db-main.log" 2>&1
git -C "$DBREPO" checkout -q -b feature
( cd "$DBREPO" && sh "$DB_HOOK" ) > "$TMP/db-feat.log" 2>&1
git -C "$DBREPO" checkout -q main
# shellcheck disable=SC2016  # backtick yaml fence is literal, not a subshell
printf '# t\n\n## ship config\n\n```yaml\ndefault_branch_ok: true\n```\n' > "$DBREPO/CLAUDE.md"
( cd "$DBREPO" && sh "$DB_HOOK" ) > "$TMP/db-optout.log" 2>&1
if grep -q "committing directly to 'main' (the default branch)" "$TMP/db-main.log" \
   && [[ ! -s "$TMP/db-feat.log" ]] \
   && [[ ! -s "$TMP/db-optout.log" ]]; then
  ok "hook default-branch: warns on main, silent on a feature branch + with default_branch_ok"
else
  nope "hook default-branch: warn/silence/opt-out wrong (see $TMP/db-main.log / feat / optout)"
fi

# ── block-env-files: real .env stays blocked, TEMPLATE names are committable.
# Field feedback: `.env.ejemplo` (referenced by the repo's own setup guide as
# `cp .env.ejemplo .env`) was blocked, forcing a rename and a doc edit. Only
# `.env.example` had an exception. Content is still scanned by gitleaks-staged.
ENV_HOOK="$(grep -l 'env files staged' "$TMP"/block*.sh 2>/dev/null | head -1)"
if [[ -n "$ENV_HOOK" ]]; then
  ok "hook: block-env-files block present in lefthook-base.yml pre-commit"
  ENVREPO="$TMP/env-templates"
  make_repo "$ENVREPO"
  # templates: must pass
  printf 'API_KEY=\n' > "$ENVREPO/.env.ejemplo"
  printf 'API_KEY=\n' > "$ENVREPO/.env.example"
  printf 'API_KEY=\n' > "$ENVREPO/.env.sample"
  git -C "$ENVREPO" add -A
  ( cd "$ENVREPO" && sh "$ENV_HOOK" ) > "$TMP/envt.log" 2>&1; envt_rc=$?
  # a real .env: must block
  printf 'API_KEY=live\n' > "$ENVREPO/.env"
  git -C "$ENVREPO" add -f .env 2>/dev/null
  ( cd "$ENVREPO" && sh "$ENV_HOOK" ) > "$TMP/envr.log" 2>&1; envr_rc=$?
  if [[ "$envt_rc" -eq 0 && ! -s "$TMP/envt.log" ]] \
     && [[ "$envr_rc" -eq 1 ]] && grep -q "BLOCKED" "$TMP/envr.log"; then
    ok "hook block-env-files: .env.ejemplo/.example/.sample pass, a real .env still blocks"
  else
    nope "hook block-env-files: template/real split wrong (t=$envt_rc r=$envr_rc, see $TMP/envt.log)"
  fi
fi

# ── tasks-archive-nudge: completed tasks left in TASK_TODO are announced on push.
# ship delegates archiving to pm-tasks, but a cycle closed without a formal /ship
# leaves [x] items behind and the monthly archive stops telling the truth.
TN_HOOK="$(grep -l 'completed task(s) still in' "$TMP"/block*.sh 2>/dev/null | head -1)"
if [[ -n "$TN_HOOK" ]]; then
  ok "hook: tasks-archive-nudge block present in lefthook-base.yml pre-push"
  TNREPO="$TMP/tasks-nudge"
  make_repo "$TNREPO"
  mkdir -p "$TNREPO/docs"
  printf -- '- [x] shipped one\n- [ ] still pending\n  - [X] shipped two\n' > "$TNREPO/docs/TASK_TODO.md"
  ( cd "$TNREPO" && sh "$TN_HOOK" ) > "$TMP/tn-hit.log" 2>&1; tn_rc=$?
  printf -- '- [ ] only pending\n' > "$TNREPO/docs/TASK_TODO.md"
  ( cd "$TNREPO" && sh "$TN_HOOK" ) > "$TMP/tn-clean.log" 2>&1
  if [[ "$tn_rc" -eq 0 ]] \
     && grep -q "2 completed task(s) still in docs/TASK_TODO.md" "$TMP/tn-hit.log" \
     && grep -q "pm-tasks archive" "$TMP/tn-hit.log" \
     && [[ ! -s "$TMP/tn-clean.log" ]]; then
    ok "hook tasks-archive-nudge: counts [x] items, points at /pm-tasks archive, silent when none, exit 0"
  else
    nope "hook tasks-archive-nudge: wrong count/silence (rc=$tn_rc, see $TMP/tn-hit.log)"
  fi
fi
