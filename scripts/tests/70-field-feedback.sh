# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL/FLOWKIT come from 00-helpers.sh via the runner
# ── 0.1.1 field feedback: --verify, unhook, --team portability, stack-aware
# ship config, baseline context labels, published-site guard, upgrade refresh ──

if command -v lefthook >/dev/null 2>&1 && command -v gitleaks >/dev/null 2>&1; then
  FF_GCFG="$TMP/ff-gitconfig"; : > "$FF_GCFG"
  git config --file "$FF_GCFG" core.excludesFile "$TMP/ff-global-ignore"

  run_ff() { # isolated env, everything into $TMP; args = install.sh args
    AGENTS_SKILLS_DIR="$TMP/ff-agents" CLAUDE_SKILLS_DIR="$TMP/ff-claude" \
      GIT_CONFIG_GLOBAL="$FF_GCFG" bash "$INSTALL" "$@" \
      > "$TMP/out.log" 2> "$TMP/err.log" < /dev/null
  }

  # ── (1) verify on a healthy wired repo: PASS, exit 0, install closes with it
  FFOK="$TMP/ff-ok"
  make_repo "$FFOK"
  if run_ff --repo "$FFOK"; then
    if grep -q -- "-- verify: PASS" "$TMP/out.log" \
       && grep -q "ok pre-commit: effective hooksPath invokes lefthook" "$TMP/out.log" \
       && grep -q "ok gitleaks:" "$TMP/out.log"; then
      ok "install closes with the effective-state verification (verify: PASS)"
    else
      nope "install did not close with a real verify report (see $TMP/out.log)"
    fi
  else
    nope "healthy wire for the verify fixture exited non-zero"
  fi
  if run_ff --repo "$FFOK" --verify; then
    if grep -q -- "-- verify: PASS" "$TMP/out.log" && grep -q "ok config:" "$TMP/out.log"; then
      ok "--verify standalone: healthy repo reports PASS, exit 0"
    else
      nope "--verify standalone: exit 0 but report lines missing (see $TMP/out.log)"
    fi
  else
    nope "--verify standalone: healthy wired repo must exit 0"
  fi
  if ( cd "$FFOK" && GIT_CONFIG_GLOBAL="$FF_GCFG" "$FLOWKIT" hooks --verify ) \
       > "$TMP/ff-fk-verify.log" 2>&1 \
     && grep -q -- "-- verify: PASS" "$TMP/ff-fk-verify.log"; then
    ok "flowkit hooks --verify: dispatches to the effective-state check, exit 0"
  else
    nope "flowkit hooks --verify: dispatch failed (see $TMP/ff-fk-verify.log)"
  fi

  # ── (1) verify on a repo with LOCAL tracked hooksPath (trs .githooks case):
  # stubs in .git/hooks are dead code -> NOT active, exit 1
  FFTRK="$TMP/ff-tracked-hp"
  make_repo "$FFTRK"
  mkdir -p "$FFTRK/.githooks"
  printf '#!/bin/sh\n# project-owned hook\nexit 0\n' > "$FFTRK/.githooks/pre-commit"
  chmod +x "$FFTRK/.githooks/pre-commit"
  git -C "$FFTRK" add .githooks
  git -C "$FFTRK" -c user.email=t@t.t -c user.name=t commit -q -m "versioned hooks"
  git -C "$FFTRK" config core.hooksPath .githooks
  run_ff --repo "$FFTRK" || true   # wiring is honest but exits 0 (conscious-skip path)
  if run_ff --repo "$FFTRK" --verify; then
    nope "--verify: tracked-hooksPath repo (stubs never invoked) must exit 1"
  elif grep -q "hooks NOT active" "$TMP/out.log" \
       && grep -q -- "-- verify: FAIL" "$TMP/out.log"; then
    ok "--verify: tracked hooksPath -> hooks NOT active, exit 1"
  else
    nope "--verify: exit 1 but NOT-active report missing (see $TMP/out.log)"
  fi

  # ── (2) published-site guard: docs/CNAME degrades the /doctos recommendation
  FFPUB="$TMP/ff-published"
  make_repo "$FFPUB"
  mkdir -p "$FFPUB/docs"
  printf 'example.com\n' > "$FFPUB/docs/CNAME"
  # a fence in CLAUDE.md: the /doctos guidance travels ATTACHED to the fence
  # finding (a standalone second line used to duplicate it)
  # shellcheck disable=SC2016  # backticks are literal markdown fences
  printf '# CLAUDE.md\n\n```js\nconsole.log(1)\n```\n' > "$FFPUB/CLAUDE.md"
  if run_ff --repo "$FFPUB"; then
    hits="$(grep -ic "indings only -- docs/ is a published site, do NOT reorganize; fix in place" "$TMP/out.log" || true)"
    if grep -q "PUBLISHED SITE" "$TMP/out.log" && [ "$hits" -eq 1 ]; then
      ok "published site: guard note + /doctos guidance attached once (no dupe)"
    else
      nope "published site: guard missing or duplicated (hits=$hits, see $TMP/out.log)"
    fi
  else
    nope "published site: install exited non-zero"
  fi

  # ── (3) --team portability: FLOW import in CLAUDE.local.md (excluded), never
  # in the committed CLAUDE.md; baseline defaults to personal (git exclude)
  FFTEAM="$TMP/ff-team"
  make_repo "$FFTEAM"
  if run_ff --repo "$FFTEAM" --team; then
    ff_excl="$FFTEAM/.git/info/exclude"
    if ! grep -qF '@~/.agents/skills/FLOW_CLAUDE.md' "$FFTEAM/CLAUDE.md" 2>/dev/null \
       && grep -qF '@~/.agents/skills/FLOW_CLAUDE.md' "$FFTEAM/CLAUDE.local.md" \
       && grep -qxF "CLAUDE.local.md" "$ff_excl"; then
      ok "--team: FLOW import lives in CLAUDE.local.md + .git/info/exclude, CLAUDE.md stays portable"
    else
      nope "--team: FLOW import leaked into CLAUDE.md or exclude entry missing"
    fi
    if grep -q "^## ship config" "$FFTEAM/CLAUDE.md"; then
      ok "--team: committed CLAUDE.md still gets the portable '## ship config' block"
    else
      nope "--team: ship config block missing from CLAUDE.md"
    fi
    if grep -qxF ".gitleaks-baseline.json" "$ff_excl" \
       && grep -q "baseline personal" "$TMP/out.log"; then
      ok "--team: baseline defaults to personal (.git/info/exclude), choice reported"
    else
      nope "--team: baseline personal default or exclude entry missing (see $TMP/out.log)"
    fi
  else
    nope "--team portability: install exited non-zero"
  fi

  # ── (4) stack detection: Cargo.toml -> cargo-flavored TODO template + suggestion
  FFCARGO="$TMP/ff-cargo"
  make_repo "$FFCARGO"
  printf '[package]\nname = "fixture"\n' > "$FFCARGO/Cargo.toml"
  if run_ff --repo "$FFCARGO"; then
    if grep -q 'TODO e.g. cargo fmt --check && cargo clippy -- -D warnings' "$FFCARGO/CLAUDE.md" \
       && grep -q 'TODO e.g. cargo test' "$FFCARGO/CLAUDE.md" \
       && grep -q "Suggested (cargo): lint: cargo fmt --check" "$TMP/out.log"; then
      ok "stack detection: Cargo.toml -> cargo template + paste-ready suggestion in agent block"
    else
      nope "stack detection: cargo template/suggestion missing (see $FFCARGO/CLAUDE.md)"
    fi
  else
    nope "stack detection: cargo fixture install exited non-zero"
  fi

  # ── (4) CI extraction: real commands from .github/workflows pre-filled and marked
  FFCI="$TMP/ff-ci"
  make_repo "$FFCI"
  printf '{ "name": "fixture" }\n' > "$FFCI/package.json"
  mkdir -p "$FFCI/.github/workflows"
  cat > "$FFCI/.github/workflows/ci.yml" <<'EOF'
name: ci
on: push
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint
      - run: npx tsc --noEmit
      - run: npm run build
      - run: npm test
EOF
  if run_ff --repo "$FFCI"; then
    if grep -q 'lint: npm run lint   # from ci.yml -- verify' "$FFCI/CLAUDE.md" \
       && grep -q 'typecheck: npx tsc --noEmit   # from ci.yml -- verify' "$FFCI/CLAUDE.md" \
       && grep -q 'build: npm run build   # from ci.yml -- verify' "$FFCI/CLAUDE.md" \
       && grep -q 'test: npm test   # from ci.yml -- verify' "$FFCI/CLAUDE.md" \
       && grep -q "Verify the CI-derived commands" "$TMP/out.log"; then
      ok "CI extraction: lint/typecheck/build/test pre-filled from ci.yml and marked for verification"
    else
      nope "CI extraction: pre-filled commands missing or unmarked (see $FFCI/CLAUDE.md)"
    fi
  else
    nope "CI extraction: fixture install exited non-zero"
  fi

  # ── (4c) 0.1.15 npm stack: read the REAL package.json scripts (no CI). Field
  # case (walter-client): the static template suggested npm run lint / npm test
  # that did not exist. Fixture has {lint, build} + a vite dep but NO test.
  FFNPM="$TMP/ff-npm-scripts"
  make_repo "$FFNPM"
  cat > "$FFNPM/package.json" <<'EOF'
{
  "name": "walter-client-fixture",
  "scripts": { "lint": "eslint .", "build": "vite build" },
  "devDependencies": { "vite": "^5.0.0" }
}
EOF
  if run_ff --repo "$FFNPM"; then
    if grep -q 'lint: npm run lint \[Vite\]   # from package.json scripts' "$FFNPM/CLAUDE.md" \
       && grep -q 'build: npm run build   # from package.json scripts' "$FFNPM/CLAUDE.md" \
       && grep -q 'test:.*no "test" script in package.json -- add one or omit' "$FFNPM/CLAUDE.md" \
       && ! grep -q '^test: npm test' "$FFNPM/CLAUDE.md"; then
      ok "npm scripts: present scripts (lint/build) suggested + Vite label; absent test named, never a phantom 'npm test'"
    else
      nope "npm scripts: template did not reflect the real package.json scripts (see $FFNPM/CLAUDE.md)"
    fi
  else
    nope "npm scripts: fixture install exited non-zero"
  fi

  # ── (5+6) baseline context: fixture-file findings tagged + REAL line shown,
  # ordinary findings stay redacted; agent block carries file:line detail
  FFBASE="$TMP/ff-baseline"
  make_repo "$FFBASE"
  FF_TOKA="dpat_$(printf 'a%.0s' {1..64})"
  FF_TOKB="dpat_$(printf 'b%.0s' {1..64})"
  mkdir -p "$FFBASE/tests"
  printf 'token = "%s"\n' "$FF_TOKA" > "$FFBASE/tests/fixtures.txt"
  printf 'token = "%s"\n' "$FF_TOKB" > "$FFBASE/prod.txt"
  git -C "$FFBASE" add tests prod.txt
  git -C "$FFBASE" -c user.email=t@t.t -c user.name=t commit -q -m "leaks"
  if run_ff --repo "$FFBASE"; then
    if grep -q "likely detector/fixture" "$TMP/out.log" \
       && grep -qF "$FF_TOKA" "$TMP/out.log"; then
      ok "baseline context: tests/fixtures finding tagged and its REAL line shown"
    else
      nope "baseline context: tag or unredacted line missing (see $TMP/out.log)"
    fi
    if ! grep -qF "$FF_TOKB" "$TMP/out.log"; then
      ok "baseline context: ordinary finding stays redacted (secret never printed)"
    else
      nope "baseline context: non-fixture secret leaked into the report"
    fi
    if grep -q "prod.txt:1 (" "$TMP/out.log" \
       && grep -q "tests/fixtures.txt:1 (" "$TMP/out.log"; then
      ok "agent block: baseline detail carries file:line per finding"
    else
      nope "agent block: file:line baseline detail missing (see $TMP/out.log)"
    fi
  else
    nope "baseline context: fixture install exited non-zero"
  fi

  # ── (7) orphan stubs: lefthook hooks without resolvable config -> verify exit 1
  FFORPH="$TMP/ff-orphan"
  make_repo "$FFORPH"
  mkdir -p "$FFORPH/.git/hooks"
  printf '#!/bin/sh\nlefthook run pre-push "$@"\n' > "$FFORPH/.git/hooks/pre-push"
  chmod +x "$FFORPH/.git/hooks/pre-push"
  if run_ff --repo "$FFORPH" --verify; then
    nope "orphan stubs: --verify must exit 1"
  elif grep -q "orphan lefthook stubs -- they will break pushes; run: flowkit unhook" "$TMP/out.log"; then
    ok "orphan stubs: --verify names them and exits 1"
  else
    nope "orphan stubs: exit 1 but the orphan line is missing (see $TMP/out.log)"
  fi

  # ── (8) unhook cleans the orphan and reports it
  if run_ff --unhook "$FFORPH"; then
    if [[ ! -f "$FFORPH/.git/hooks/pre-push" ]] \
       && grep -q "unhook report" "$TMP/out.log" \
       && grep -q "lefthook stub" "$TMP/out.log"; then
      ok "unhook: orphan stub removed and listed in the report table"
    else
      nope "unhook: orphan stub survived or report missing (see $TMP/out.log)"
    fi
  else
    nope "unhook: exited non-zero on the orphan fixture"
  fi

  # ── (8) unhook a fully wired solo repo: our config + stubs gone
  if run_ff --unhook "$FFOK"; then
    if [[ ! -f "$FFOK/lefthook.yml" ]] \
       && ! grep -qs lefthook "$FFOK/.git/hooks/pre-commit" \
       && grep -q "our config" "$TMP/out.log"; then
      ok "unhook: wired solo repo left clean (lefthook.yml + stubs removed)"
    else
      nope "unhook: wired solo repo not fully cleaned (see $TMP/out.log)"
    fi
  else
    nope "unhook: exited non-zero on the wired solo repo"
  fi

  # ── (8) unhook a --team repo: local yml + our exclude entries removed;
  # a TRACKED project lefthook.yml is respected
  printf 'pre-commit:\n  jobs: []\n' > "$FFTEAM/lefthook.yml"
  git -C "$FFTEAM" add lefthook.yml
  git -C "$FFTEAM" -c user.email=t@t.t -c user.name=t commit -q -m "own config"
  if run_ff --unhook "$FFTEAM"; then
    if [[ ! -f "$FFTEAM/lefthook-local.yml" && -f "$FFTEAM/lefthook.yml" ]] \
       && ! grep -qxF "CLAUDE.local.md" "$FFTEAM/.git/info/exclude" \
       && ! grep -qxF ".gitleaks-baseline.json" "$FFTEAM/.git/info/exclude" \
       && grep -q "tracked (project-owned) -- left in place" "$TMP/out.log" \
       && grep -q "exclude entry" "$TMP/out.log"; then
      ok "unhook --team: our yml + exclude entries removed, tracked project yml respected"
    else
      nope "unhook --team: wrong cleanup (see $TMP/out.log)"
    fi
  else
    nope "unhook --team: exited non-zero"
  fi

  # ── (9) upgrade inside a wired repo refreshes its lefthook remotes cache
  FFUPG="$TMP/ff-upgrade"
  make_repo "$FFUPG"
  cat > "$FFUPG/lefthook.yml" <<'EOF'
# wired to https://github.com/dPeluChe/skills (remotes cache fixture)
pre-commit:
  jobs: []
EOF
  ( cd "$FFUPG" && bash "$INSTALL" --upgrade ) > "$TMP/out.log" 2> "$TMP/err.log" < /dev/null
  ff_rc=$?
  if [[ "$ff_rc" -le 1 ]] && grep -q "remotes refreshed" "$TMP/out.log"; then
    ok "upgrade inside a wired repo: remotes refreshed via lefthook install, exit $ff_rc"
  else
    nope "upgrade inside a wired repo: refresh line missing or exit $ff_rc (see $TMP/out.log)"
  fi

  # ── flowkit surface: unhook + hooks --verify documented in help
  if "$FLOWKIT" help > "$TMP/ff-help.log" 2>&1 \
     && grep -q "unhook" "$TMP/ff-help.log" \
     && grep -q -- "--verify" "$TMP/ff-help.log"; then
    ok "flowkit help: unhook and hooks --verify listed"
  else
    nope "flowkit help: unhook/--verify missing (see $TMP/ff-help.log)"
  fi
else
  echo "· lefthook/gitleaks not installed — field-feedback fixtures skipped (non-fatal)"
fi
