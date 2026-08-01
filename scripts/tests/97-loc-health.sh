# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL/FLOWKIT come from 00-helpers.sh via the runner
# ── loc-health: the one mechanical dev rule (400-500 LOC/file) automated ──
# Two surfaces: pre-commit hook warns about files THIS diff grows past loc_limit
# (diff-scoped, never the repo); `flowkit loc-health` audits the whole repo.
# loc_limit comes from CLAUDE.md ship config (default 500). Advisory everywhere.

# flowkit help lists it
if "$FLOWKIT" help 2>&1 | grep -q "loc-health"; then
  ok "flowkit help: loc-health subcommand listed"
else
  nope "flowkit help: loc-health not listed"
fi

mk_shipcfg() { # $1 = repo dir, $2 = loc_limit -> CLAUDE.md with a ship config block
  {
    printf '# t\n\n## ship config\n\n```yaml\n'
    printf 'lint: true\nloc_limit: %s\n```\n' "$2"
  } > "$1/CLAUDE.md"
}

# ── (1) loc-health repo-wide: over-limit reported, under-limit clean, custom
# loc_limit honored ──────────────────────────────────────────────────────────
LC1="$TMP/loc-repo"
mkdir -p "$LC1/src"
make_repo "$LC1"
mk_shipcfg "$LC1" 20
seq 50 > "$LC1/src/big.ts"      # 50 > 20 -> over
seq 5  > "$LC1/src/small.ts"    # 5  < 20 -> fine
git -C "$LC1" add -A
if "$FLOWKIT" loc-health "$LC1" > "$TMP/loc1.log" 2>&1 \
   && grep -q "limit 20 LOC" "$TMP/loc1.log" \
   && grep -q "1 file(s) over 20 LOC" "$TMP/loc1.log" \
   && grep -q "src/big.ts" "$TMP/loc1.log" \
   && ! grep -q "src/small.ts" "$TMP/loc1.log" \
   && grep -q "^ALERT:" "$TMP/loc1.log"; then
  ok "loc-health: over-limit file reported with count, under-limit ignored, custom loc_limit honored"
else
  nope "loc-health: repo-wide audit wrong (see $TMP/loc1.log)"
fi

# ── (2) clean repo: no files over the (default 500) limit -> ok, exit 0 ───────
LC2="$TMP/loc-clean"
mkdir -p "$LC2/src"
make_repo "$LC2"
seq 30 > "$LC2/src/a.ts"
git -C "$LC2" add -A
if "$FLOWKIT" loc-health "$LC2" > "$TMP/loc2.log" 2>&1 \
   && grep -q "no files over 500 LOC" "$TMP/loc2.log" \
   && ! grep -q "ALERT" "$TMP/loc2.log"; then
  ok "loc-health: repo within the default 500 limit is clean (no ALERT, exit 0)"
else
  nope "loc-health: clean repo should report ok (see $TMP/loc2.log)"
fi

# ── (3) denylist: a huge lockfile / generated file is NOT a design smell ──────
LC3="$TMP/loc-skip"
mkdir -p "$LC3/src" "$LC3/convex/_generated"
make_repo "$LC3"
mk_shipcfg "$LC3" 20
seq 9000 > "$LC3/package-lock.json"          # lockfile -> skip
seq 9000 > "$LC3/convex/_generated/api.ts"   # generated -> skip
seq 50   > "$LC3/src/real.ts"                # real code over limit -> report
git -C "$LC3" add -A
if "$FLOWKIT" loc-health "$LC3" > "$TMP/loc3.log" 2>&1 \
   && grep -q "src/real.ts" "$TMP/loc3.log" \
   && ! grep -q "package-lock.json" "$TMP/loc3.log" \
   && ! grep -q "_generated" "$TMP/loc3.log"; then
  ok "loc-health: lockfile + generated skipped, real over-limit code reported"
else
  nope "loc-health: denylist did not exclude lockfile/generated (see $TMP/loc3.log)"
fi

# ── (4) dispatch parity: flowkit loc-health == install.sh --loc-health ────────
"$FLOWKIT" loc-health "$LC1" > "$TMP/loc-fk.log" 2>&1; lfk=$?
bash "$INSTALL" --loc-health "$LC1" > "$TMP/loc-direct.log" 2>&1; ldir=$?
if [[ "$lfk" -eq "$ldir" ]] && cmp -s "$TMP/loc-fk.log" "$TMP/loc-direct.log"; then
  ok "dispatch: flowkit loc-health byte-identical to install.sh --loc-health (rc $lfk)"
else
  nope "dispatch: flowkit loc-health diverges from install.sh --loc-health (rc $lfk vs $ldir)"
fi

# ── (5) pre-commit hook: warn ONLY on files THIS commit grows past loc_limit ──
LC_HOOK="$(grep -l 'grew it' "$TMP"/block*.sh 2>/dev/null | head -1)"
if [[ -n "$LC_HOOK" ]]; then
  ok "hook: loc-warning (diff-aware) block present in lefthook-base.yml pre-commit"
else
  nope "hook: diff-aware loc-warning block missing"
  return 0
fi

LC5="$TMP/loc-hook"
make_repo "$LC5"
mk_shipcfg "$LC5" 10
seq 8 > "$LC5/f.txt"
git -C "$LC5" add -A
git -C "$LC5" -c user.email=t@t.t -c user.name=t commit -q -m base

# grow past the limit -> WARN
seq 20 > "$LC5/f.txt"; git -C "$LC5" add f.txt
( cd "$LC5" && sh "$LC_HOOK" ) > "$TMP/loc5a.log" 2>&1
git -C "$LC5" -c user.email=t@t.t -c user.name=t commit -q -m grow
# shrink an over-limit file (still over) -> SILENT
seq 12 > "$LC5/f.txt"; git -C "$LC5" add f.txt
( cd "$LC5" && sh "$LC_HOOK" ) > "$TMP/loc5b.log" 2>&1
# new file under the limit -> SILENT
git -C "$LC5" -c user.email=t@t.t -c user.name=t commit -q -m shrink
seq 5 > "$LC5/small.txt"; git -C "$LC5" add small.txt
( cd "$LC5" && sh "$LC_HOOK" ) > "$TMP/loc5c.log" 2>&1

if grep -q "f.txt has 20 lines (>10)" "$TMP/loc5a.log" \
   && grep -q "grew it (+12)" "$TMP/loc5a.log" \
   && [[ ! -s "$TMP/loc5b.log" ]] \
   && [[ ! -s "$TMP/loc5c.log" ]]; then
  ok "hook loc-warning: grew-past-limit warns (custom loc_limit 10); shrink + under-limit silent"
else
  nope "hook loc-warning: diff-aware behavior wrong (see $TMP/loc5a.log / b / c)"
fi
