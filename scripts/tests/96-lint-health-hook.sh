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
