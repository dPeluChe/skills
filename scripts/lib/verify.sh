# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (REPO_DIR, REMOTE_URL via util, ...) come from install.sh
# ── verify: effective hook state -- merged jobs, canary probe, full report ──
# Sourced by scripts/install.sh (the entrypoint); never executed directly.

lefthook_jobs_count() { # $1 = target repo, $2 = hook; how many jobs/commands the
  # MERGED config (lefthook dump: local + remotes cache) resolves for that hook.
  # Prints 0 when the config is inert or unparseable -- that IS the finding.
  ( cd "$1" && lefthook dump -f json 2>/dev/null ) | python3 -c '
import json, sys
try:
    cfg = json.load(sys.stdin)
except Exception:
    print(0)
    raise SystemExit
hook = cfg.get(sys.argv[1]) or {}
print(len(hook.get("jobs") or []) + len(hook.get("commands") or {}))
' "$2" 2>/dev/null || echo 0
}

canary_secret_scan() { # $1 = target repo. EFFICACY probe of the EFFECTIVE gate:
  # stage a synthetic AWS-style key in an ISOLATED temp index (GIT_INDEX_FILE)
  # and run the pre-commit hook GIT ITSELF would run (core.hooksPath local >
  # global > .git/hooks -- effective_hooks_dir). That one pass covers
  # config -> hooksPath -> lefthook -> merged jobs -> gitleaks: a placebo state
  # (stubs wired, 0 jobs merged) now fails HERE, not only in the jobs check.
  # The user's real index is never touched; the temp index is removed.
  # Returns 0 = hook BLOCKED the canary (exit != 0 + "leaks found" evidence),
  # 1 = canary passed unseen (or the hook failed without leak evidence --
  # a crash is not a working gate), 2 = probe could not run,
  # 3 = no effective pre-commit hook exists.
  # (Canary value assembled at runtime so no secret-shaped literal lives here.)
  local target="$1" gitdir tmpidx blob rc=1 out canary hookfile
  canary="$(printf 'AKIA%s' "2J94QXKZR7T3W8Y5")"
  git -C "$target" rev-parse HEAD >/dev/null 2>&1 || return 2
  gitdir="$(git -C "$target" rev-parse --absolute-git-dir)" || return 2
  hookfile="$(effective_hooks_dir "$target")/pre-commit"
  [[ -x "$hookfile" ]] || return 3
  tmpidx="$gitdir/flowkit-canary-index.$$"
  rm -f "$tmpidx"
  blob="$(printf 'canary_key = "%s"\n' "$canary" \
    | git -C "$target" hash-object -w --stdin)" || return 2
  ( cd "$target" \
    && GIT_INDEX_FILE="$tmpidx" git read-tree HEAD \
    && GIT_INDEX_FILE="$tmpidx" git update-index --add \
         --cacheinfo "100644,$blob,flowkit-canary-probe.txt" \
  ) >/dev/null 2>&1 || { rm -f "$tmpidx"; return 2; }
  # the verdict comes from the hook git executes, never from a direct scanner
  # call: "the scanner would flag it" is not "the commit gets blocked".
  # Warm-up run first: lefthook fetches its remotes cache on the FIRST run and
  # executes the just-fetched jobs even when the steady-state merge is empty
  # (overlay-only placebo blocks exactly once, then goes inert) -- the verdict
  # that matters is the SECOND run's: what every future commit gets.
  ( cd "$target" && GIT_INDEX_FILE="$tmpidx" "$hookfile" ) >/dev/null 2>&1 || true
  if out="$(cd "$target" && GIT_INDEX_FILE="$tmpidx" "$hookfile" 2>&1)"; then
    rc=1   # the commit would have gone through
  elif grep -q "leaks found" <<<"$out"; then
    rc=0   # blocked, and blocked BY the secret -- not a crash
  else
    rc=1
  fi
  rm -f "$tmpidx"
  return "$rc"
}

lefthook_cfg_file() { # $1 = target; prints the config file referencing our remote
  local target="$1" f
  for f in lefthook.yml lefthook-local.yml; do
    if [[ -f "$target/$f" ]] && grep -qF "$REMOTE_URL" "$target/$f"; then
      printf '%s\n' "$f"; return 0
    fi
  done
  return 1
}

hook_invokes_lefthook() { # $1 = target, $2 = hook name; does the hook git will
  # ACTUALLY run invoke lefthook (directly, or via a chain wrapper delegating to
  # a lefthook stub in .git/hooks)?
  local target="$1" hook="$2" ehp file gitdir
  ehp="$(effective_hooks_dir "$target")"
  file="$ehp/$hook"
  [[ -f "$file" ]] || return 1
  grep -q lefthook "$file" && return 0
  if grep -q 'git rev-parse --git-dir' "$file"; then
    gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
    [[ -f "$gitdir/hooks/$hook" ]] && grep -q lefthook "$gitdir/hooks/$hook" && return 0
  fi
  return 1
}

verify_repo_hooks() { # $1 = target repo. EFFECTIVE-state verification: config
  # present + the hooks git actually runs invoke lefthook + the merged config
  # resolves REAL jobs + gitleaks accessible (and which config it uses) + a
  # canary secret is actually flagged + no orphan stubs. A hook consciously
  # skipped via `hooks_skip: <hook>: reason` in the ship config block reports
  # ok-skipped instead of failing. Prints a report; returns 0 active / 1 not.
  local target="$1" rc=0 cfg="" ehp gitdir hook f stubs=0 resolvable=0
  local skip_reason jobs
  ehp="$(effective_hooks_dir "$target")"
  gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
  echo "-- verify: effective hook state ($target)"
  if cfg="$(lefthook_cfg_file "$target")"; then
    echo "ok config: $cfg references $REMOTE_URL"
  else
    echo "x config: no lefthook.yml/lefthook-local.yml referencing $REMOTE_URL"
    rc=1
  fi
  # a security declaration is never dropped in silence: a hooks_skip key in a
  # format neither parser understands gets a loud WARN instead of being ignored
  if ship_hooks_skip_unparseable "$target"; then
    echo "! WARN: hooks_skip present but unparseable -- declaration ignored (use 'hooks_skip:' + indented '<hook>: \"reason\"' lines, or the one-line 'hooks_skip: <hook>: \"reason\"')"
  fi
  for hook in pre-commit pre-push commit-msg; do
    skip_reason="$(ship_hooks_skip_reason "$target" "$hook")"
    if [[ -n "$skip_reason" ]]; then
      echo "ok $hook (skipped: $skip_reason) -- conscious skip declared in ship config hooks_skip"
      continue
    fi
    if hook_invokes_lefthook "$target" "$hook"; then
      echo "ok $hook: effective hooksPath invokes lefthook"
    else
      echo "x $hook: hooks NOT active -- the hook git runs ($ehp/$hook) never invokes lefthook"
      rc=1
    fi
  done
  # wiring can be perfect and the gate still INERT: the merged config must
  # resolve real jobs (field case: only lefthook-local.yml present -> 0 jobs)
  if [[ -n "$cfg" ]] && command -v lefthook >/dev/null 2>&1 \
     && [[ -z "$(ship_hooks_skip_reason "$target" pre-commit)" ]]; then
    jobs="$(lefthook_jobs_count "$target" pre-commit)"
    if [[ "$jobs" -gt 0 ]]; then
      echo "ok jobs: pre-commit resolves $jobs job(s) (lefthook dump)"
    else
      if [[ -f "$target/lefthook-local.yml" && ! -f "$target/lefthook.yml" ]]; then
        echo "x jobs: pre-commit resolves 0 jobs -- only personal overlay present; without a base config lefthook merges no jobs (lefthook-local.yml alone is inert: write lefthook.yml with the remotes block, or re-run: flowkit hooks)"
      else
        echo "x jobs: pre-commit resolves 0 jobs ('lefthook dump') -- the gate is inert (empty config or remotes cache never fetched; run: flowkit upgrade inside this repo to refresh it)"
      fi
      rc=1
    fi
  fi
  if command -v lefthook >/dev/null 2>&1; then
    echo "ok lefthook: $(tool_version lefthook) accessible"
  else
    echo "x lefthook: not found (brew install lefthook)"
    rc=1
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    echo "ok gitleaks: $(tool_version gitleaks) accessible"
    if [[ -f "$target/.gitleaks.toml" ]]; then
      echo "ok gitleaks config: repo-local .gitleaks.toml (replaces the central rules -- keep '[extend] useDefault = true' inside it)"
    else
      echo "ok gitleaks config: central (hooks/.gitleaks.toml via lefthook remotes)"
    fi
    # canary: prove EFFICACY, not just wiring -- a synthetic secret staged in
    # an isolated temp index must be BLOCKED by the pre-commit hook git runs
    if [[ -n "$(ship_hooks_skip_reason "$target" pre-commit)" ]]; then
      echo "- canary: skipped (pre-commit consciously skipped via hooks_skip)"
    else
      canary_secret_scan "$target"
      case "$?" in
        0) echo "ok canary: synthetic secret staged in an isolated index IS blocked by the effective pre-commit hook ($(gitleaks_config_label "$target"))" ;;
        1) echo "x canary: a synthetic AWS-style key passed the effective pre-commit hook UNSEEN ($(gitleaks_config_label "$target")) -- the secret gate is ineffective (inert config merging 0 jobs, dropped rules -- a repo-local .gitleaks.toml must keep [extend] useDefault = true -- or a hook crash without a leak verdict)"
           rc=1 ;;
        3) echo "x canary: no effective pre-commit hook -- git would run NOTHING at commit time (expected at $ehp/pre-commit)"
           rc=1 ;;
        *) echo "- canary: probe could not run (no HEAD yet?) -- efficacy unproven, wiring checks above still hold" ;;
      esac
    fi
  else
    echo "x gitleaks: not found -- secret scan will be skipped (brew install gitleaks)"
    rc=1
  fi
  # orphan stubs: lefthook hook files present while no config resolves --
  # lefthook errors out on every push instead of running jobs
  for f in "$ehp"/* "$gitdir"/hooks/*; do
    [[ -f "$f" ]] && grep -q lefthook "$f" 2>/dev/null && { stubs=1; break; }
  done
  if [[ "$stubs" == 1 ]]; then
    if [[ -n "$cfg" ]] && command -v lefthook >/dev/null 2>&1 \
       && ( cd "$target" && lefthook dump >/dev/null 2>&1 ); then
      resolvable=1
    fi
    if [[ "$resolvable" == 0 ]]; then
      echo "x orphan lefthook stubs -- they will break pushes; run: flowkit unhook"
      rc=1
    fi
  fi
  if [[ "$rc" -eq 0 ]]; then
    echo "-- verify: PASS (hooks active end-to-end)"
  else
    echo "-- verify: FAIL -- hooks are NOT fully active in this repo"
  fi
  return "$rc"
}
