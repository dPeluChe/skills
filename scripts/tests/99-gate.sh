# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR come from 00-helpers.sh via the runner
# ── flowkit gate + the pre-push scan of every pushed commit: the layer for
#    pushes where git hooks do not run (/ship watch, CI, GUI clients) ─────────

GATE="$REPO_DIR/scripts/gate.sh"
if command -v gitleaks >/dev/null 2>&1; then
  GT="$TMP/gate-repo"
  make_repo "$GT"
  git -C "$GT" branch -M main
  git -C "$GT" update-ref refs/remotes/origin/main HEAD
  base_sha="$(git -C "$GT" rev-parse HEAD)"
  # shellcheck disable=SC2016  # literal markdown fence
  printf '# t\n\n## preship config\n\n```yaml\nlint: echo linted # why\ntypecheck: false\n```\n' > "$GT/CLAUDE.md"
  git -C "$GT" add CLAUDE.md
  git -C "$GT" -c user.email=t@t.t -c user.name=t commit -qm config
  clean_sha="$(git -C "$GT" rev-parse HEAD)"

  ( bash "$GATE" "$GT" ) > "$TMP/gate1.log" 2>&1; rc=$?
  if [[ "$rc" -eq 1 ]] && grep -q '^ok secrets' "$TMP/gate1.log" \
     && grep -q '^ok lint: echo linted$' "$TMP/gate1.log" && grep -q '^x typecheck: false' "$TMP/gate1.log"; then
    ok "gate: clean range passes secrets, runs lint (comment stripped), a failing typecheck fails the gate"
  else
    nope "gate: wrong verdicts on a clean range (rc=$rc, see $TMP/gate1.log)"
  fi

  # a commit made with hooks OFF, as the /ship watch does
  # GitHub PAT shape: caught by gitleaks' default rules, so no central config needed
  printf 'token = "%s%s"\n' "ghp_" "R8kLmN2pQ7sT4vW9xY3zA6bC1dE5fG0hJ2kM" > "$GT/a.cfg"
  git -C "$GT" add a.cfg
  git -C "$GT" -c core.hooksPath=/dev/null -c user.email=t@t.t -c user.name=t commit -qm leak
  leak_sha="$(git -C "$GT" rev-parse HEAD)"

  ( bash "$GATE" --secrets-only "$GT" ) > "$TMP/gate2.log" 2>&1; rc=$?
  if [[ "$rc" -eq 1 ]] && grep -q '^x secrets' "$TMP/gate2.log" && grep -q 'File: *a.cfg' "$TMP/gate2.log"; then
    ok "gate: a secret committed with hooks off is caught in the range, file named"
  else
    nope "gate: secret in the range not caught (rc=$rc, see $TMP/gate2.log)"
  fi

  PP_HOOK="$(grep -l 'pushed-commit scan SKIPPED' "$TMP"/block*.sh 2>/dev/null | head -1)"
  if [[ -n "$PP_HOOK" ]]; then
    z=0000000000000000000000000000000000000000
    ( cd "$GT" && printf 'refs/heads/main %s refs/heads/main %s\n' "$leak_sha" "$base_sha" | sh "$PP_HOOK" ) \
      > "$TMP/pp1.log" 2>&1; rc_leak=$?
    ( cd "$GT" && printf 'refs/heads/main %s refs/heads/main %s\n' "$clean_sha" "$base_sha" | sh "$PP_HOOK" ) \
      > "$TMP/pp2.log" 2>&1; rc_clean=$?
    ( cd "$GT" && printf '(delete) %s refs/heads/old %s\n' "$z" "$leak_sha" | sh "$PP_HOOK" ) \
      > "$TMP/pp3.log" 2>&1; rc_del=$?
    git -C "$GT" checkout -q -b feature
    ( cd "$GT" && printf 'refs/heads/feature %s refs/heads/feature %s\n' "$leak_sha" "$z" | sh "$PP_HOOK" ) \
      > "$TMP/pp4.log" 2>&1; rc_new=$?
    if [[ "$rc_leak" -ne 0 && "$rc_clean" -eq 0 && "$rc_del" -eq 0 && "$rc_new" -ne 0 ]]; then
      ok "pre-push gitleaks-pushed: blocks a leaked commit (existing + new branch), passes clean, ignores deletions"
    else
      nope "pre-push gitleaks-pushed: leak=$rc_leak clean=$rc_clean delete=$rc_del new-branch=$rc_new (see $TMP/pp*.log)"
    fi
  else
    nope "pre-push gitleaks-pushed block not found in lefthook-base.yml"
  fi
fi
