# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL/BASE_YML/WRAPPER come from earlier modules via the runner
# ── 0.1.3 browv2 feedback: no-block by construction (docs-nudge / gate
# fail-soft), git-guard assignment-position semantics, unhook without
# lefthook, about orphan hint, compact lefthook output ──

inject_crash() { # $1 = src script, $2 = dst, $3 = line injected after the first lone '{'
  awk -v inj="$3" 'BEGIN{done=0} {print} !done && /^\{$/ {print inj; done=1}' "$1" > "$2"
}

# ── (1) docs-nudge INCAPABLE of blocking: crash injected inside the guarded
# group must still exit 0 -- under plain sh AND sh -e (errexit is how the
# field 127 killed pushes) ──
NUDGE80="$(grep -l 'no docs touched' "$TMP"/block*.sh | head -1 || true)"
if [[ -n "$NUDGE80" ]]; then
  mkdir -p "$TMP/nb80-fix"
  sed "s|{push_files}|src/app.ts|" "$NUDGE80" > "$TMP/nb80-sub.sh"
  inject_crash "$TMP/nb80-sub.sh" "$TMP/nb80-crash.sh" "  flowkit_missing_cmd_127_fixture"
  if grep -q "flowkit_missing_cmd_127_fixture" "$TMP/nb80-crash.sh" \
     && ( cd "$TMP/nb80-fix" && sh "$TMP/nb80-crash.sh" ) >/dev/null 2>&1 \
     && ( cd "$TMP/nb80-fix" && sh -e "$TMP/nb80-crash.sh" ) >/dev/null 2>&1; then
    ok "docs-nudge: injected crash in the body still exits 0 (sh + sh -e) -- no-block by construction"
  else
    nope "docs-nudge: a crash in the body must never block (expected exit 0)"
  fi
else
  nope "docs-nudge block not found for the crash-injection fixture"
fi

# ── (1) ship-config-gate structural fail-soft: config-reading machinery
# crash degrades to warning + exit 0; deliberate lint failures still block ──
if [[ -n "$WRAPPER" ]]; then
  make_fixture "$TMP/fix80-valid" <<'EOF'
# Test repo

## ship config

```yaml
lint: true
```
EOF
  sed "s|{push_files}|src/app.ts|" "$WRAPPER" > "$TMP/gate80-sub.sh"
  # sabotage sed: block extraction dies -> empty commands -> fail-soft path
  inject_crash "$TMP/gate80-sub.sh" "$TMP/gate80-crash.sh" '  sed() { return 127; }'
  if ( cd "$TMP/fix80-valid" && sh -e "$TMP/gate80-crash.sh" ) \
       > "$TMP/out.log" 2> "$TMP/err.log"; then
    if grep -q "no ship config block" "$TMP/err.log"; then
      ok "ship-config-gate: wrapper crash (sed sabotaged, sh -e) degrades to warning + exit 0"
    else
      nope "ship-config-gate: crash degraded but the loud warning is missing"
    fi
  else
    nope "ship-config-gate: wrapper crash must degrade to exit 0, never a stray non-zero"
  fi
  # a stray crash must NOT swallow a real lint failure either
  make_fixture "$TMP/fix80-failing" <<'EOF'
# Test repo

## ship config

```yaml
lint: false
```
EOF
  inject_crash "$TMP/gate80-sub.sh" "$TMP/gate80-crash2.sh" "  flowkit_missing_cmd_127_fixture"
  if ( cd "$TMP/fix80-failing" && sh -e "$TMP/gate80-crash2.sh" ) \
       > "$TMP/out.log" 2> "$TMP/err.log"; then
    nope "ship-config-gate: real lint failure must still block despite a stray crash"
  else
    ok "ship-config-gate: real lint failure still blocks (exit 1) with a stray crash present"
  fi
else
  nope "ship-config-gate block not found for the crash-injection fixtures"
fi

# ── (2) git-guard: bypass vars only in ASSIGNMENT position, prose is data ──
GG80="$REPO_DIR/hooks/harness/git-guard.sh"
if [[ -x "$GG80" ]]; then
  if run_gg 'gh pr create --title "guard docs" --body "never bypass hooks with LEFTHOOK=0 or --no-verify in this repo"' \
     && [[ ! -s "$TMP/err.log" ]]; then
    ok "git-guard: LEFTHOOK=0 in PR-body prose passes silently (gh pr create)"
  else
    nope "git-guard: prose mention of LEFTHOOK=0 in a PR body must not block"
  fi
  if run_gg 'echo "docs about LEFTHOOK=0"' && [[ ! -s "$TMP/err.log" ]]; then
    ok "git-guard: echo of a doc line mentioning LEFTHOOK=0 passes"
  else
    nope "git-guard: echo 'docs about LEFTHOOK=0' must pass"
  fi
  gg80_bad=0
  GG80_BLOCK=(
    "LEFTHOOK=0 git push"
    "env LEFTHOOK=0 git push"
    "export LEFTHOOK=0 && git push"
    "cd repo; LEFTHOOK=0 git push"
  )
  for cmd in "${GG80_BLOCK[@]}"; do
    run_gg "$cmd"; rc=$?
    if [[ "$rc" -ne 2 || ! -s "$TMP/err.log" ]]; then
      nope "git-guard: assignment bypass NOT blocked (rc=$rc): $cmd"
      gg80_bad=1
    fi
  done
  [[ "$gg80_bad" -eq 0 ]] && ok "git-guard: ${#GG80_BLOCK[@]} LEFTHOOK= assignment forms block with exit 2"
  if run_gg 'FLOWKIT_GIT_GUARD=off git push --force origin main' \
     && grep -q "FLOWKIT_GIT_GUARD=off" "$TMP/err.log"; then
    ok "git-guard: FLOWKIT_GIT_GUARD=off assigned on the command works as the escape hatch"
  else
    nope "git-guard: command-assigned FLOWKIT_GIT_GUARD=off should pass with a warning"
  fi
  # 0.1.8: the documented remedy must work where the need is -- inside loops
  if run_gg 'while read b; do FLOWKIT_GIT_GUARD=off git branch -D "$b"; done < lista' \
     && grep -q "FLOWKIT_GIT_GUARD=off" "$TMP/err.log"; then
    ok "git-guard: escape hatch works inside a loop body (after 'do')"
  else
    nope "git-guard: FLOWKIT_GIT_GUARD=off after 'do' must work (documented remedy)"
  fi
  run_gg 'while read b; do git branch -D "$b"; done < lista'; rc=$?
  if [[ "$rc" -eq 2 ]]; then
    ok "git-guard: loop WITHOUT the override still blocks branch -D"
  else
    nope "git-guard: unguarded loop branch -D must block (rc=$rc)"
  fi
  run_gg 'git commit --no-verify -m "docs mention FLOWKIT_GIT_GUARD=off"'; rc=$?
  if [[ "$rc" -eq 2 ]]; then
    ok "git-guard: prose mention of FLOWKIT_GIT_GUARD=off does NOT disarm the guard"
  else
    nope "git-guard: --no-verify with a prose escape mention must still block (rc=$rc)"
  fi
else
  nope "hooks/harness/git-guard.sh missing or not executable (0.1.3 fixtures)"
fi

# ── (3) broken state: orphan stubs with NO lefthook config at all ──
BRK80="$TMP/brk80"
make_repo "$BRK80"
mkdir -p "$BRK80/.git/hooks"
printf '#!/bin/sh\nlefthook run pre-commit "$@"\n' > "$BRK80/.git/hooks/pre-commit"
chmod +x "$BRK80/.git/hooks/pre-commit"
# about (dynamic section) surfaces the orphan + the unhook suggestion
if ( cd "$BRK80" && bash "$INSTALL" --about ) > "$TMP/out.log" 2>&1 \
   && grep -q "orphan stubs" "$TMP/out.log" \
   && grep -q "flowkit unhook" "$TMP/out.log"; then
  ok "about: orphan stubs detected in the dynamic section, flowkit unhook suggested"
else
  nope "about: orphan-stub hint missing (see $TMP/out.log)"
fi
# unhook must clean the stubs WITHOUT lefthook (PATH masked) and with no config
if env PATH=/usr/bin:/bin bash "$INSTALL" --unhook "$BRK80" \
     > "$TMP/out.log" 2> "$TMP/err.log"; then
  if [[ ! -f "$BRK80/.git/hooks/pre-commit" ]] \
     && grep -q "lefthook stub" "$TMP/out.log"; then
    ok "unhook: broken state (stubs, zero configs, lefthook NOT in PATH) -> exit 0, stubs removed"
  else
    nope "unhook: stub survived or report missing in the broken state (see $TMP/out.log)"
  fi
else
  nope "unhook: must exit 0 in the broken state without lefthook available"
fi

# ── (4) compact output pinned in the base config ──
if grep -q '^output:' "$BASE_YML" \
   && grep -q '^  - summary$' "$BASE_YML" \
   && grep -q '^  - execution_out$' "$BASE_YML" \
   && grep -q '^  - failure$' "$BASE_YML"; then
  ok "lefthook-base.yml: output pinned compact (summary + execution_out + failure)"
else
  nope "lefthook-base.yml: top-level output allowlist missing or incomplete"
fi
if command -v lefthook >/dev/null 2>&1; then
  LHC80="$TMP/lh-compact"
  make_repo "$LHC80"
  cp "$BASE_YML" "$LHC80/lefthook.yml"
  git -C "$LHC80" config core.hooksPath "$LHC80/.git/hooks"
  echo "clean content" > "$LHC80/file.txt"
  git -C "$LHC80" add file.txt
  if ( cd "$LHC80" && lefthook run pre-commit ) > "$TMP/out.log" 2>&1; then
    if ! grep -q "lefthook v" "$TMP/out.log" \
       && ! grep -q "❯" "$TMP/out.log" \
       && grep -q "summary:" "$TMP/out.log"; then
      ok "compact output live: no meta banner / job decoration, short summary kept"
    else
      nope "compact output live: banner or decoration leaked (see $TMP/out.log)"
    fi
  else
    nope "compact output live: clean pre-commit run should exit 0 (see $TMP/out.log)"
  fi
else
  echo "· lefthook not installed — compact-output live fixture skipped (non-fatal)"
fi
