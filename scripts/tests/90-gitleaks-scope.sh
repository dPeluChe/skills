# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL/FLOWKIT/BASE_YML come from 00-helpers.sh via the runner
# ── 0.1.4 field feedback: repo-local .gitleaks.toml scope (central rules are
# blind to project-specific secret formats) + verify measures EFFICACY, not
# wiring (0-jobs inert gate, canary probe, hooks_skip, commit-msg breakdown,
# flowkit hooks --help) ──
# ── 0.1.5 field feedback: the canary runs the EFFECTIVE pre-commit hook (the
# file git executes), so a placebo gate fails by canary, not only by the jobs
# diagnostic; hooks_skip accepts one-line AND nested-map forms, and an
# unrecognized format WARNs instead of being ignored in silence ──

# README: the repo-local pattern, the portability note and hooks_skip must be
# documented (no tools required for this check)
if grep -q "useDefault = true" "$REPO_DIR/README.md" \
   && grep -q "NOT portable" "$REPO_DIR/README.md" \
   && grep -q "hooks_skip" "$REPO_DIR/README.md"; then
  ok "README: repo-local gitleaks pattern + portability note + hooks_skip documented"
else
  nope "README: repo-local gitleaks / hooks_skip documentation missing"
fi

if command -v lefthook >/dev/null 2>&1 && command -v gitleaks >/dev/null 2>&1; then
  GS_GCFG="$TMP/gs-gitconfig"; : > "$GS_GCFG"
  git config --file "$GS_GCFG" core.excludesFile "$TMP/gs-global-ignore"

  run_gs() { # isolated env, everything into $TMP; args = install.sh args
    AGENTS_SKILLS_DIR="$TMP/gs-agents" CLAUDE_SKILLS_DIR="$TMP/gs-claude" \
      GIT_CONFIG_GLOBAL="$GS_GCFG" bash "$INSTALL" "$@" \
      > "$TMP/out.log" 2> "$TMP/err.log" < /dev/null
  }

  # browv2-style CSPRNG token: 40 hex chars, shape invisible to the default +
  # central rules (entropy below the generic threshold) — assembled at runtime
  # so this source file never carries a secret-shaped literal
  GS_TOK="$(printf '4f9d8c2b1e%.0s' {1..4})"

  write_project_gitleaks() { # $1 = repo dir; extend useDefault + project rule
    cat > "$1/.gitleaks.toml" <<'EOF'
title = "project rules"

[extend]
useDefault = true

[[rules]]
id = "project-csprng-token"
description = "project 40-char CSPRNG token"
regex = '''\b[a-f0-9]{40}\b'''
EOF
  }

  # ── (1) blindness: a staged project token PASSES pre-commit on central rules
  GSBLIND="$TMP/gs-blind"
  make_repo "$GSBLIND"
  cp "$BASE_YML" "$GSBLIND/lefthook.yml"
  printf 'access_token = "%s"\n' "$GS_TOK" > "$GSBLIND/service-config.txt"
  git -C "$GSBLIND" add service-config.txt
  if ( cd "$GSBLIND" && GIT_CONFIG_GLOBAL="$GS_GCFG" lefthook run pre-commit ) \
       > "$TMP/out.log" 2>&1; then
    ok "blindness: project CSPRNG token invisible to central rules (pre-commit exit 0)"
  else
    nope "blindness fixture: pre-commit should pass WITHOUT a repo-local config (see $TMP/out.log)"
  fi

  # ── (1) cure: repo-local .gitleaks.toml with the project rule BLOCKS it
  write_project_gitleaks "$GSBLIND"
  if ( cd "$GSBLIND" && GIT_CONFIG_GLOBAL="$GS_GCFG" lefthook run pre-commit ) \
       > "$TMP/out.log" 2>&1; then
    nope "cure: repo-local .gitleaks.toml rule did NOT block the staged token"
  else
    ok "cure: repo-local .gitleaks.toml (extend useDefault + project rule) blocks pre-commit"
  fi

  # ── (2) central path: baseline + verify name the config, agent block nudges
  GSCENT="$TMP/gs-central"
  make_repo "$GSCENT"
  if run_gs --repo "$GSCENT"; then
    if grep -q "config: central hooks/.gitleaks.toml" "$TMP/out.log" \
       && grep -q "ok gitleaks config: central (hooks/.gitleaks.toml via lefthook remotes)" "$TMP/out.log"; then
      ok "central path: baseline and verify both name the central config"
    else
      nope "central path: config-in-use labels missing (see $TMP/out.log)"
    fi
    # nudge must warn a local config REPLACES the central (downgrade risk),
    # not just "add one" -- field feedback: naive add loses central coverage
    if grep -q "it REPLACES the central config" "$TMP/out.log" \
       && grep -q "do NOT add one" "$TMP/out.log"; then
      ok "agent block: nudge warns local .gitleaks.toml replaces central (no naive-add downgrade)"
    else
      nope "agent block: replace-warning nudge missing (see $TMP/out.log)"
    fi
  else
    nope "central path: install exited non-zero"
  fi

  # ── (3) repo-local path: baseline honors project rules, verify labels it,
  # nudge absent (the repo already made its decision)
  GSLOCAL="$TMP/gs-local"
  make_repo "$GSLOCAL"
  write_project_gitleaks "$GSLOCAL"
  printf 'access_token = "%s"\n' "$GS_TOK" > "$GSLOCAL/historic.txt"
  git -C "$GSLOCAL" add historic.txt
  git -C "$GSLOCAL" -c user.email=t@t.t -c user.name=t commit -q -m "historic token"
  if run_gs --repo "$GSLOCAL"; then
    if grep -q "config: repo-local .gitleaks.toml" "$TMP/out.log" \
       && grep -q "baseline: 1 findings" "$TMP/out.log" \
       && grep -q "ok gitleaks config: repo-local .gitleaks.toml" "$TMP/out.log"; then
      ok "repo-local path: baseline caught the project token (1 finding) + verify labels the config"
    else
      nope "repo-local path: baseline finding or config label missing (see $TMP/out.log)"
    fi
    if ! grep -q "add a repo-local .gitleaks.toml" "$TMP/out.log"; then
      ok "agent block: repo WITH .gitleaks.toml gets no redundant nudge"
    else
      nope "agent block: nudge printed despite an existing .gitleaks.toml"
    fi
  else
    nope "repo-local path: install exited non-zero"
  fi

  # ── (4) canary catches an INEFFECTIVE config: rules dropped (no extend,
  # no rules) -> EVERY panel shape passes unseen -> verify FAIL, all named
  GSBROKE="$TMP/gs-broken-cfg"
  make_repo "$GSBROKE"
  printf 'title = "empty config -- no extend, no rules"\n' > "$GSBROKE/.gitleaks.toml"
  run_gs --repo "$GSBROKE" || true   # wiring finishes; the verify inside already flags it
  if run_gs --repo "$GSBROKE" --verify; then
    nope "canary: an empty repo-local config must FAIL --verify"
  elif grep -q "x canary: shape(s) passed the effective pre-commit hook UNSEEN" "$TMP/out.log" \
       && grep -q "postgres-uri: UNSEEN" "$TMP/out.log" \
       && grep -q "dpat: UNSEEN" "$TMP/out.log" \
       && grep -q -- "-- verify: FAIL" "$TMP/out.log"; then
    ok "canary: empty repo-local .gitleaks.toml -> whole panel unseen by the real hook, verify exit 1"
  else
    nope "canary: exit 1 but the canary panel diagnosis is missing (see $TMP/out.log)"
  fi

  # ── (4b) THE crown-jewel case: a repo-local config that KEEPS [extend]
  # useDefault = true (so AWS/generic still caught by defaults) but DROPS one
  # central custom rule (postgres). An AWS-only canary would stay GREEN here;
  # the panel must FAIL naming exactly the dropped shape (TASK-108 class).
  GSDROP="$TMP/gs-drop-postgres"
  make_repo "$GSDROP"
  cat > "$GSDROP/.gitleaks.toml" <<'EOF'
title = "useDefault kept, postgres rule dropped"
[extend]
useDefault = true
[[rules]]
id = "dpeluche-dpat"
regex = '''dpat_[a-f0-9]{64}'''
keywords = ["dpat_"]
[[rules]]
id = "dpeluche-sentry-dsn"
regex = '''https://[a-f0-9]{8,64}@[A-Za-z0-9.-]*sentry\.io/[0-9]+'''
keywords = ["sentry.io"]
[[rules]]
id = "dpeluche-iteris-sync-token"
regex = '''ITERIS_SYNC_TOKEN\s*[=:]\s*['"]?[A-Za-z0-9_\-]{8,}'''
keywords = ["ITERIS_SYNC_TOKEN"]
EOF
  run_gs --repo "$GSDROP" || true
  if run_gs --repo "$GSDROP" --verify; then
    nope "canary drop-rule: a config that dropped the postgres rule must FAIL --verify"
  elif grep -q "x canary: shape(s) passed the effective pre-commit hook UNSEEN: postgres-uri" "$TMP/out.log" \
       && grep -q "postgres-uri: UNSEEN" "$TMP/out.log" \
       && grep -q "dpat: caught" "$TMP/out.log" \
       && grep -q "sentry-dsn: caught" "$TMP/out.log" \
       && grep -q -- "-- verify: FAIL" "$TMP/out.log"; then
    ok "canary drop-rule: useDefault kept but postgres rule dropped -> canary names postgres-uri UNSEEN, verify exit 1"
  else
    nope "canary drop-rule: postgres not isolated as the dropped shape (see $TMP/out.log)"
  fi

  # ── (5) 0-jobs inert gate (field state): ONLY lefthook-local.yml present --
  # wiring checks all pass (stubs + config), the MERGED config resolves nothing
  GSINERT="$TMP/gs-inert"
  make_repo "$GSINERT"
  printf 'remotes:\n  - git_url: %s\n    ref: main\n    refetch_frequency: 24h\n    configs:\n      - hooks/lefthook-base.yml\n' \
    "$REMOTE_URL" > "$GSINERT/lefthook-local.yml"
  for h in pre-commit pre-push commit-msg; do
    printf '#!/bin/sh\nlefthook run %s "$@"\n' "$h" > "$GSINERT/.git/hooks/$h"
    chmod +x "$GSINERT/.git/hooks/$h"
  done
  if run_gs --repo "$GSINERT" --verify; then
    nope "0-jobs: overlay-only repo must FAIL --verify (the gate is inert)"
  elif grep -q "x jobs: pre-commit resolves 0 jobs" "$TMP/out.log" \
       && grep -q "only personal overlay present; without a base config lefthook merges no jobs" "$TMP/out.log"; then
    ok "0-jobs: lefthook-local.yml alone -> inert gate detected and named, verify exit 1"
  else
    nope "0-jobs: exit 1 but the overlay-only diagnosis is missing (see $TMP/out.log)"
  fi
  # the placebo state must ALSO fail by canary: the effective hook runs, merges
  # 0 jobs, exits 0 -> the canary sails through the very hook git would run.
  # (0.1.4 canary called gitleaks directly and stayed GREEN here.)
  if grep -q "x canary: shape(s) passed the effective pre-commit hook UNSEEN" "$TMP/out.log"; then
    ok "0-jobs: canary fails through the EFFECTIVE hook too (verdict, not just the jobs diagnostic)"
  else
    nope "0-jobs: canary stayed green on a placebo gate (see $TMP/out.log)"
  fi

  # ── (5b) no effective pre-commit hook at all: canary names the void
  GSNOHOOK="$TMP/gs-nohook"
  make_repo "$GSNOHOOK"
  cp "$BASE_YML" "$GSNOHOOK/lefthook.yml"   # config present, stubs never installed
  if run_gs --repo "$GSNOHOOK" --verify; then
    nope "no-hook: repo without any pre-commit hook must FAIL --verify"
  elif grep -q "x canary: no effective pre-commit hook" "$TMP/out.log"; then
    ok "no-hook: canary FAILs with 'no effective pre-commit hook' (git would run nothing)"
  else
    nope "no-hook: exit 1 but the no-effective-hook diagnosis is missing (see $TMP/out.log)"
  fi

  # ── (6) hooks_skip: a deliberate, recorded skip is ok, not a permanent FAIL
  GSSKIP="$TMP/gs-skip"
  make_repo "$GSSKIP"
  run_gs --repo "$GSSKIP" || true
  rm -f "$GSSKIP/.git/hooks/pre-push"
  if run_gs --repo "$GSSKIP" --verify; then
    nope "hooks_skip control: missing pre-push stub without a declared skip must FAIL"
  else
    ok "hooks_skip control: missing pre-push stub fails verify (exit 1)"
  fi
  cat > "$GSSKIP/CLAUDE.md" <<'EOF'
# Test repo

## ship config

```yaml
lint: true
hooks_skip: pre-push: "CI runs the same lint on every push"
```
EOF
  if run_gs --repo "$GSSKIP" --verify; then
    if grep -q "ok pre-push (skipped: CI runs the same lint on every push)" "$TMP/out.log"; then
      ok "hooks_skip one-line form: declared skip reported as ok-skipped with its reason, verify exit 0"
    else
      nope "hooks_skip one-line form: exit 0 but the skipped line is missing (see $TMP/out.log)"
    fi
  else
    nope "hooks_skip one-line form: a declared conscious skip must not FAIL verify"
  fi

  # ── (6b) nested map form -- the plain YAML anyone writes -- must work too
  # (0.1.4 ignored it IN SILENCE and verify failed on a declared skip)
  cat > "$GSSKIP/CLAUDE.md" <<'EOF'
# Test repo

## ship config

```yaml
lint: true
hooks_skip:
  pre-push: "CI runs the same lint on every push"
```
EOF
  if run_gs --repo "$GSSKIP" --verify; then
    if grep -q "ok pre-push (skipped: CI runs the same lint on every push)" "$TMP/out.log" \
       && ! grep -q "hooks_skip present but unparseable" "$TMP/out.log"; then
      ok "hooks_skip nested map: declared skip honored (no unparseable WARN), verify exit 0"
    else
      nope "hooks_skip nested map: exit 0 but skipped line missing or spurious WARN (see $TMP/out.log)"
    fi
  else
    nope "hooks_skip nested map: valid YAML map must not FAIL verify"
  fi

  # ── (6c) unrecognized format (flow list): loud WARN, declaration ignored,
  # verify FAILs on the actually-missing pre-push -- never a silent discard
  cat > "$GSSKIP/CLAUDE.md" <<'EOF'
# Test repo

## ship config

```yaml
lint: true
hooks_skip: [pre-push]
```
EOF
  if run_gs --repo "$GSSKIP" --verify; then
    nope "hooks_skip unparseable: ignored declaration must FAIL verify (pre-push stub missing)"
  elif grep -q "hooks_skip present but unparseable -- declaration ignored" "$TMP/out.log" \
       && grep -q "x pre-push: hooks NOT active" "$TMP/out.log"; then
    ok "hooks_skip unparseable: explicit WARN + declaration ignored, verify exit 1"
  else
    nope "hooks_skip unparseable: exit 1 but WARN or pre-push failure missing (see $TMP/out.log)"
  fi

  # ── (7) verify breakdown on a healthy repo (central config): commit-msg +
  # merged jobs + the WHOLE panel caught; canary leaves no trace in the repo
  if run_gs --repo "$GSCENT" --verify \
     && grep -q "ok commit-msg: effective hooksPath invokes lefthook" "$TMP/out.log" \
     && grep -q "ok jobs: pre-commit resolves" "$TMP/out.log" \
     && grep -q "ok canary: panel of synthetic secrets (one per central rule) ALL blocked by the effective pre-commit hook" "$TMP/out.log" \
     && grep -q "postgres-uri: caught" "$TMP/out.log" \
     && grep -q "sentry-dsn: caught" "$TMP/out.log" \
     && grep -q "iteris-token: caught" "$TMP/out.log" \
     && grep -q "generic-high-entropy: caught" "$TMP/out.log" \
     && ! grep -q "UNSEEN" "$TMP/out.log"; then
    ok "verify breakdown: central config -> commit-msg + jobs + FULL canary panel caught (no UNSEEN)"
  else
    nope "verify breakdown: commit-msg/jobs/panel lines missing or a shape UNSEEN (see $TMP/out.log)"
  fi
  gs_leftover=("$GSCENT"/.git/*canary*)
  if [[ -z "$(git -C "$GSCENT" diff --cached --name-only)" ]] \
     && [[ ! -e "${gs_leftover[0]}" ]]; then
    ok "canary hygiene: real index untouched, temp index removed"
  else
    nope "canary hygiene: leftovers in the real index or .git"
  fi

  # ── (8) flowkit hooks --help: help, not 'unknown --repo option: --help'
  if ( cd "$GSCENT" && GIT_CONFIG_GLOBAL="$GS_GCFG" "$FLOWKIT" hooks --help ) \
       > "$TMP/gs-help.log" 2>&1 \
     && grep -q "Usage: flowkit" "$TMP/gs-help.log" \
     && ! grep -q "unknown --repo option" "$TMP/gs-help.log"; then
    ok "flowkit hooks --help: shows the general help, exit 0"
  else
    nope "flowkit hooks --help: dispatch broken (see $TMP/gs-help.log)"
  fi

  # ── (9) fresh repo (ZERO commits): the canary needs a HEAD to stage its probe,
  # so it DEFERS -- a legitimate pre-commit state, NOT a failure. verify must PASS
  # + exit 0 (field feedback: a no-HEAD repo read as verify FAIL). Own clean git
  # config so nothing but the no-HEAD state can affect the verdict.
  GSFRESH="$TMP/gs-fresh"; mkdir -p "$GSFRESH"; git -C "$GSFRESH" init -q
  GSF_GCFG="$TMP/gs-fresh-gitconfig"; : > "$GSF_GCFG"
  git config --file "$GSF_GCFG" core.excludesFile "$TMP/gs-fresh-ignore"
  # < /dev/null: never block on the interactive team prompt (as run_gs does)
  gsf_run() { AGENTS_SKILLS_DIR="$TMP/gsf-a" CLAUDE_SKILLS_DIR="$TMP/gsf-c" \
    GIT_CONFIG_GLOBAL="$GSF_GCFG" bash "$INSTALL" "$@" < /dev/null; }
  gsf_run --repo "$GSFRESH" >/dev/null 2>&1
  if gsf_run --repo "$GSFRESH" --verify > "$TMP/gs-fresh.log" 2>&1 \
     && grep -q "canary: DEFERRED" "$TMP/gs-fresh.log" \
     && grep -q "verify: PASS" "$TMP/gs-fresh.log"; then
    ok "fresh repo (no HEAD): canary DEFERRED + verify PASS + exit 0 (not a failure)"
  else
    nope "fresh repo: no-commit must defer the canary + PASS, not FAIL (see $TMP/gs-fresh.log)"
  fi

  # ── (10) displaced hook: lefthook replaces a repo's OWN .git/hooks/pre-commit
  # and backs it up to .old without running it -- the repo's hook silently stops
  # firing. verify must SCREAM (not report green), install must warn, and the
  # secret gate must NOT be masked (flowkit does NOT auto-chain: an old hook's
  # exit 0 would let a caught secret through). Field feedback (regression report).
  GSDISP="$TMP/gs-displaced"; mkdir -p "$GSDISP"; git -C "$GSDISP" init -q
  git -C "$GSDISP" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m init
  printf '#!/bin/sh\necho custom-hook\n' > "$GSDISP/.git/hooks/pre-commit"
  chmod +x "$GSDISP/.git/hooks/pre-commit"
  gsf_run --repo "$GSDISP" > "$TMP/gs-disp-install.log" 2>&1
  gsf_run --repo "$GSDISP" --verify > "$TMP/gs-disp.log" 2>&1; gs_disp_rc=$?
  if [[ "$gs_disp_rc" -ne 0 ]] \
     && grep -q "displaced hook: a pre-existing pre-commit" "$TMP/gs-disp.log" \
     && grep -q "ALL blocked by the effective pre-commit" "$TMP/gs-disp.log" \
     && grep -q "displaced by lefthook" "$TMP/gs-disp-install.log"; then
    ok "displaced hook: verify SCREAMS + install warns + the secret gate still blocks (not masked, not silent)"
  else
    nope "displaced hook: must scream + warn + keep the gate intact (see $TMP/gs-disp.log)"
  fi
else
  echo "· lefthook/gitleaks not installed — gitleaks-scope fixtures skipped (non-fatal)"
fi

# ── problem_summary repeats each problem next to the count -- the problem line
# otherwise ends ~28 lines above the verdict (field feedback). Pure util unit.
# shellcheck disable=SC1091,SC2034  # util.sh sourced at runtime; PROBLEMS used by bad()
( source "$REPO_DIR/scripts/lib/util.sh"; PROBLEMS=0
  bad "chain wrapper(s) missing for: pre-commit pre-push" >/dev/null
  problem_summary ) > "$TMP/ps.log" 2>&1
if grep -q "1 problem(s) found" "$TMP/ps.log" \
   && grep -q "x chain wrapper(s) missing for: pre-commit pre-push" "$TMP/ps.log"; then
  ok "problem_summary: repeats the problem line next to 'N problem(s) found'"
else
  nope "problem_summary: problem not echoed next to the summary (see $TMP/ps.log)"
fi
