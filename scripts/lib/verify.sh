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

canary_panel() { # prints "label<TAB>line-content": 6 shapes = 5 of the 6 central
  # custom rules in hooks/.gitleaks.toml + one DEFAULT-ruleset shape (proves
  # [extend] useDefault = true is still on). `dpeluche-github-pat` is deliberately
  # unshaped: a ghp_ value also matches gitleaks' own default github-pat rule, so
  # it cannot separate the custom rule from the default one, and it would appear
  # as a second label in the useDefault differential the guard asserts.
  #
  # Two constraints shape this function:
  # 1. Values are ASSEMBLED from split fragments so no secret-shaped literal
  #    ever lives here: this repo scans its own source, and a literal would be
  #    blocked by the very gate the panel probes.
  # 2. Values are DETERMINISTIC. A probe must never feed a random input to a
  #    heuristically-filtered rule: random draws hit gitleaks' generic-api-key
  #    STOPWORD filter ~1% of the time and were reported as a gate regression.
  #    Root cause, evidence and arithmetic: docs/FEATURES/CANARY_DETERMINISM.md.
  #
  # The postgres host avoids 'example'/'placeholder' -- those are allowlisted
  # and would make a real block read as UNSEEN.
  local hex64 hex32 akia strp iter24 pgpw
  hex64="$(printf '0123456789abcdef%.0s' 1 2 3 4)"
  hex32="$(printf '0123456789abcdef%.0s' 1 2)"
  akia="$(printf 'AKIA%s' '2J94QXKZR7T3W8Y5')"
  # strict-format DEFAULT rule (stripe-access-token): no entropy or stopword
  # heuristic, so it is caught whenever useDefault is on and missed the moment
  # it is turned off, which is the regression this shape exists to catch
  strp='sk_''live_''4eC39HqLyjWDarjtT1zdp7dc'
  iter24="$(printf 'Kq7Xm2Vt%.0s' 1 2 3)"
  pgpw="$(printf 'Rn5Wd8Jb%.0s' 1 2)"
  printf 'dpat\ttoken = "dpat_%s"\n' "$hex64"
  printf 'aws\tkey = "%s"\n' "$akia"
  printf 'postgres-uri\turl = "%s%s:%s%s"\n' 'postgres''ql://' 'svcuser' "$pgpw" '@db.prod.internal/appdb'
  printf 'sentry-dsn\tdsn = "https://%s@o987654.ingest.sentry.io/7654321"\n' "$hex32"
  printf 'iteris-token\tITERIS_SYNC_TOKEN=sync_%s\n' "$iter24"
  printf 'default-ruleset\tkey = "%s"\n' "$strp"
}

canary_secret_scan() { # $1 = target repo. EFFICACY probe of the EFFECTIVE gate,
  # per SHAPE. Stage each synthetic secret from canary_panel in its OWN
  # ISOLATED temp index (GIT_INDEX_FILE) and run the pre-commit hook GIT ITSELF
  # would run (core.hooksPath local > global > .git/hooks -- effective_hooks_dir).
  # Each probe covers config -> hooksPath -> lefthook -> merged jobs -> gitleaks.
  # Testing a PANEL (not one shape) catches the TASK-108 class: a repo-local
  # .gitleaks.toml that keeps [extend] useDefault = true but DROPS a central
  # custom rule (dpat_/postgres/Sentry/ITERIS) still blocks an AWS-only canary
  # (AWS is a default) while it silently stopped catching the dropped shape.
  # Reports which shapes are caught vs UNSEEN via CANARY_REPORT / CANARY_UNSEEN;
  # the verdict for every shape comes from the hook, never a direct scanner call.
  # The user's real index is never touched; each temp index is removed.
  # Returns 0 = every shape BLOCKED, 1 = at least one shape passed UNSEEN
  # (dropped rule / hook crash without a leak verdict), 2 = probe could not run,
  # 3 = no effective pre-commit hook exists, 4 = no HEAD yet (fresh repo -- a
  # legitimate state, NOT a failure: the canary is deferred until the first commit).
  local target="$1" gitdir tmpidx blob out hookfile label content
  local -a unseen=()
  CANARY_REPORT=""; CANARY_UNSEEN=""
  git -C "$target" rev-parse HEAD >/dev/null 2>&1 || return 4
  gitdir="$(git -C "$target" rev-parse --absolute-git-dir)" || return 2
  hookfile="$(effective_hooks_dir "$target")/pre-commit"
  [[ -x "$hookfile" ]] || return 3
  tmpidx="$gitdir/flowkit-canary-index.$$"

  stage_one() { # $1 = filename, $2 = line content -> fresh isolated temp index
    rm -f "$tmpidx"
    blob="$(printf '%s\n' "$2" | git -C "$target" hash-object -w --stdin)" || return 1
    ( cd "$target" \
      && GIT_INDEX_FILE="$tmpidx" git read-tree HEAD \
      && GIT_INDEX_FILE="$tmpidx" git update-index --add \
           --cacheinfo "100644,$blob,$1" \
    ) >/dev/null 2>&1
  }

  # Warm-up run first: lefthook fetches its remotes cache on the FIRST run and
  # executes the just-fetched jobs even when the steady-state merge is empty
  # (overlay-only placebo blocks exactly once, then goes inert) -- the verdict
  # that matters is the STEADY-STATE run's, what every future commit gets. Do
  # it ONCE, before the per-shape loop, so no single shape absorbs the warm-up.
  if ! stage_one "flowkit-canary-warmup.txt" '# flowkit canary warm-up (no secret)'; then
    rm -f "$tmpidx"; return 2
  fi
  ( cd "$target" && GIT_INDEX_FILE="$tmpidx" "$hookfile" ) >/dev/null 2>&1 || true

  while IFS=$'\t' read -r label content; do
    [[ -n "$label" ]] || continue
    if ! stage_one "flowkit-canary-$label.txt" "$content"; then
      rm -f "$tmpidx"; return 2
    fi
    # the verdict comes from the hook git executes, never from a direct scanner
    # call: "the scanner would flag it" is not "the commit gets blocked".
    if out="$(cd "$target" && GIT_INDEX_FILE="$tmpidx" "$hookfile" 2>&1)"; then
      CANARY_REPORT+="  - $label: UNSEEN"$'\n'   # the commit would have gone through
      unseen+=("$label")
    elif grep -q "leaks found" <<<"$out"; then
      CANARY_REPORT+="  - $label: caught"$'\n'   # blocked, and blocked BY the secret
    else
      CANARY_REPORT+="  - $label: UNSEEN (hook failed without a leak verdict)"$'\n'
      unseen+=("$label")
    fi
  done < <(canary_panel)
  rm -f "$tmpidx"

  # ${arr[*]:-} not ${arr[*]}: an EMPTY array (all shapes caught -> success) under
  # `set -u` is an "unbound variable" fatal in bash 3.2 (macOS system bash), the
  # very case that means the gate WORKS. Caught by CI (runner bash 3.2 vs dev 5.x).
  CANARY_UNSEEN="${unseen[*]:-}"
  [[ "${#unseen[@]}" -eq 0 ]] || return 1
  return 0
}

hookspath_pin_stale() { # $1 = target. 0 when this repo was wired BEFORE the local
  # core.hooksPath pin existed: a GLOBAL hooksPath is in play and the repo has no
  # local pin, so lefthook retries its hook sync on every run, cannot complete it,
  # and reprints the ~30-line "core.hooksPath is set globally" block forever.
  # The hooks DO run, so this is a staleness WARNING, never a verify failure.
  # Fix is one command: flowkit hooks.
  local gp
  gp="$(git config --global core.hooksPath 2>/dev/null || true)"
  [[ -n "$gp" ]] || return 1
  [[ -z "$(git -C "$1" config --local --get core.hooksPath 2>/dev/null || true)" ]]
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
  # husky indirection: git runs .husky/_/<hook>, a two-line stub that sources the
  # loader `h`, which then runs .husky/<hook> -- exactly where flowkit's own
  # installer puts the delegation line. Inspecting only the stub reported
  # "hooks NOT active" on a repo whose gate was provably blocking secrets: a
  # false RED on a security check, which sends people to fix what already works
  # and teaches them to ignore the check. Follow one level up.
  # shellcheck disable=SC2016  # the pattern is literal shell text inside the stub
  if grep -qE 'dirname "\$0"|\$\(dirname' "$file" 2>/dev/null; then
    local up
    up="$(dirname "$ehp")/$hook"
    [[ -f "$up" ]] && grep -q lefthook "$up" && return 0
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
    # canary: prove EFFICACY, not just wiring -- a PANEL of synthetic secrets,
    # one per central custom rule, each staged in its own isolated temp index
    # and required to be BLOCKED by the pre-commit hook git runs. Per-shape
    # report names exactly which rule stopped blocking, not just "something".
    if [[ -n "$(ship_hooks_skip_reason "$target" pre-commit)" ]]; then
      echo "- canary: skipped (pre-commit consciously skipped via hooks_skip)"
    else
      canary_secret_scan "$target"
      case "$?" in
        0) echo "ok canary: panel of synthetic secrets (one per central rule) ALL blocked by the effective pre-commit hook ($(gitleaks_config_label "$target"))"
           printf '%s' "$CANARY_REPORT" ;;
        1) echo "x canary: shape(s) passed the effective pre-commit hook UNSEEN: $CANARY_UNSEEN ($(gitleaks_config_label "$target")) -- these central rules stopped blocking (dropped rules -- a repo-local .gitleaks.toml must keep [extend] useDefault = true AND re-declare the central rules -- inert config merging 0 jobs, or a hook crash without a leak verdict)"
           printf '%s' "$CANARY_REPORT"
           rc=1 ;;
        3) echo "x canary: no effective pre-commit hook -- git would run NOTHING at commit time (expected at $ehp/pre-commit)"
           rc=1 ;;
        4) echo "- canary: DEFERRED -- no commit yet (fresh repo); efficacy is probed from the first commit on. Wiring above is active (not a failure)." ;;
        *) echo "- canary: probe could not run -- efficacy unproven, wiring checks above still hold" ;;
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
  # displaced repo hook: wiring backs a pre-existing .git/hooks/<hook> up to
  # <hook>.old but the installed stub does NOT chain to it -- the repo's OWN hook
  # was replaced and no longer runs. --verify used to miss this (it checks the
  # hooks flowkit MANAGES, not the one it displaced) and reported green. It must
  # SCREAM (field feedback): the declared 'wired ok' diverged from the effective
  # 'your own hook is dead'. A hooksPath set elsewhere kills .git/hooks/* too.
  local hk oldf
  for hk in pre-commit pre-push commit-msg; do
    oldf="$gitdir/hooks/$hk.old"
    [[ -f "$oldf" ]] || continue
    if ! grep -qF "$hk.old" "$gitdir/hooks/$hk" 2>/dev/null; then
      echo "x displaced hook: a pre-existing $hk was replaced by wiring and no longer runs"
      echo "  (backed up at .git/hooks/$hk.old, NOT chained). Restore delegation (chain it) or"
      echo "  migrate its logic into lefthook / the ## ship config -- don't leave it silently dead."
      rc=1
    fi
  done
  # staleness, not failure: the wiring works, it is just the older convention and
  # it costs ~30 lines of lefthook noise on every git operation in this repo
  if hookspath_pin_stale "$target"; then
    echo "! stale wiring: no local core.hooksPath pin, so lefthook retries its sync every run"
    echo "  (that is the repeated 'core.hooksPath is set globally' block). Re-run: flowkit hooks"
  fi
  if [[ "$rc" -eq 0 ]]; then
    echo "-- verify: PASS (hooks active end-to-end)"
  else
    echo "-- verify: FAIL -- hooks are NOT fully active in this repo"
  fi
  return "$rc"
}
