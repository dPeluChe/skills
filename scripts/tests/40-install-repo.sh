# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL come from 00-helpers.sh via the runner
# ── install.sh --repo: workspace mode, hooksPath cases, --team, --upgrade ───

if command -v lefthook >/dev/null 2>&1 && command -v gitleaks >/dev/null 2>&1; then
  # isolated environment: skills chain dirs + git global config live in $TMP
  ENV_AGENTS="$TMP/agents-skills"; ENV_CLAUDE="$TMP/claude-skills"
  GCFG_NONE="$TMP/gitconfig-none"; : > "$GCFG_NONE"

  run_install() { # $1 = global gitconfig file, rest = install.sh args
    local gcfg="$1"; shift
    AGENTS_SKILLS_DIR="$ENV_AGENTS" CLAUDE_SKILLS_DIR="$ENV_CLAUDE" \
      GIT_CONFIG_GLOBAL="$gcfg" bash "$INSTALL" "$@" \
      > "$TMP/out.log" 2> "$TMP/err.log" < /dev/null
  }

  # workspace: parent repo + two git children + one plain dir
  WS="$TMP/ws"
  make_repo "$WS"
  make_repo "$WS/child-a"
  make_repo "$WS/child-b"
  mkdir -p "$WS/not-a-repo"
  if run_install "$GCFG_NONE" --repo "$WS"; then
    if grep -q "workspace detected: 2 child repo(s)" "$TMP/out.log" \
       && grep -q "workspace report" "$TMP/out.log" \
       && grep -q "child-a" "$TMP/out.log" && grep -q "child-b" "$TMP/out.log" \
       && [[ -f "$WS/child-a/lefthook.yml" && -f "$WS/child-b/lefthook.yml" ]] \
       && [[ ! -f "$WS/lefthook.yml" ]]; then
      ok "workspace: 2 children wired with report table, parent skipped by default"
    else
      nope "workspace: wrong detection/wiring (see $TMP/out.log)"
    fi
  else
    nope "workspace: install.sh --repo exited non-zero on a healthy workspace"
  fi

  # workspace + --include-parent: parent gets wired too
  WS2="$TMP/ws2"
  make_repo "$WS2"
  make_repo "$WS2/child-c"
  if run_install "$GCFG_NONE" --repo "$WS2" --include-parent; then
    if [[ -f "$WS2/lefthook.yml" && -f "$WS2/child-c/lefthook.yml" ]] \
       && grep -q "(parent)" "$TMP/out.log"; then
      ok "workspace: --include-parent wires the parent as well"
    else
      nope "workspace: --include-parent did not wire the parent"
    fi
  else
    nope "workspace: --include-parent run exited non-zero"
  fi

  # plain repo (no children): previous single-repo behavior
  SINGLE="$TMP/single"
  make_repo "$SINGLE"
  if run_install "$GCFG_NONE" --repo "$SINGLE"; then
    if [[ -f "$SINGLE/lefthook.yml" ]] && ! grep -q "workspace detected" "$TMP/out.log"; then
      ok "single repo: wired directly, no workspace mode"
    else
      nope "single repo: unexpected workspace detection or missing lefthook.yml"
    fi
  else
    nope "single repo: install.sh --repo exited non-zero"
  fi

  # agent-docs fences: CLAUDE.md/AGENTS.md with code fences beyond the ship
  # config yaml one -> counted and /doctos recommended (never blocks)
  FENCED="$TMP/fenced"
  make_repo "$FENCED"
  cat > "$FENCED/CLAUDE.md" <<'EOF'
# Test repo

## ship config

```yaml
lint: true
```

## dev commands

```bash
npm run dev
```
EOF
  cat > "$FENCED/AGENTS.md" <<'EOF'
# Agents

```js
console.log("embedded");
```
EOF
  if run_install "$GCFG_NONE" --repo "$FENCED"; then
    if grep -q "2 embedded code blocks in CLAUDE.md/AGENTS.md" "$TMP/out.log"; then
      ok "agent-docs fences: 2 extra fences counted, /doctos recommended, exit 0"
    else
      nope "agent-docs fences: fence count/notice missing (see $TMP/out.log)"
    fi
    if grep -q -- "---- copy below to your agent ----" "$TMP/out.log" \
       && grep -q "Run /doctos on this repo: 2 embedded code blocks" "$TMP/out.log" \
       && grep -q "For context on this tooling run .flowkit about." "$TMP/out.log" \
       && grep -q "if flowkit is not on PATH, read" "$TMP/out.log" \
       && grep -q "hooks/lefthook-base.yml in the skills repo" "$TMP/out.log"; then
      ok "agent block: actionable findings + copy-block flowkit-not-on-PATH fallback collected"
    else
      nope "agent block: delimited section, action lines or PATH fallback missing (see $TMP/out.log)"
    fi
  else
    nope "agent-docs fences: detection must never block the install"
  fi

  CLEANDOC="$TMP/cleandoc"
  make_repo "$CLEANDOC"
  # a repo-local .gitleaks.toml so the project-formats nudge (0.1.4) does not
  # fire either -- this fixture asserts the NOTHING-actionable case. It must
  # keep [extend] useDefault = true AND re-declare the central custom rules,
  # otherwise the 0.1.15 canary panel (correctly) flags the dropped shapes.
  cat > "$CLEANDOC/.gitleaks.toml" <<'EOF'
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
id = "dpeluche-postgres-uri"
regex = '''postgres(?:ql)?://[A-Za-z0-9_.-]+:[^@/\s'"]+@[A-Za-z0-9.-]+'''
keywords = ["postgres"]
[[rules]]
id = "dpeluche-iteris-sync-token"
regex = '''ITERIS_SYNC_TOKEN\s*[=:]\s*['"]?[A-Za-z0-9_\-]{8,}'''
keywords = ["ITERIS_SYNC_TOKEN"]
EOF
  cat > "$CLEANDOC/CLAUDE.md" <<'EOF'
# Test repo

## ship config

```yaml
lint: true
```
EOF
  if run_install "$GCFG_NONE" --repo "$CLEANDOC" \
     && ! grep -q "embedded code blocks" "$TMP/out.log"; then
    ok "agent-docs fences: ship config yaml fence alone stays silent"
  else
    nope "agent-docs fences: false positive on the canonical ship config fence"
  fi
  if ! grep -q -- "---- copy below to your agent ----" "$TMP/out.log"; then
    ok "agent block: repo with nothing actionable prints no block"
  else
    nope "agent block: printed despite no actions (see $TMP/out.log)"
  fi

  # global hooksPath WITH chain wrappers: proceed, stubs land in .git/hooks
  GHOOKS="$TMP/ghooks"
  mkdir -p "$GHOOKS"
  for h in pre-commit pre-push; do
    # shellcheck disable=SC2016  # the wrapper body must expand at hook time
    printf '#!/bin/sh\nl="$(git rev-parse --git-dir)/hooks/%s"\n[ -x "$l" ] && exec "$l" "$@"\nexit 0\n' "$h" > "$GHOOKS/$h"
    chmod +x "$GHOOKS/$h"
  done
  GCFG_CHAIN="$TMP/gitconfig-chain"
  git config --file "$GCFG_CHAIN" core.hooksPath "$GHOOKS"
  CHAINED="$TMP/chained-repo"
  make_repo "$CHAINED"
  if run_install "$GCFG_CHAIN" --repo "$CHAINED"; then
    if grep -q "chain wrappers: OK" "$TMP/out.log" \
       && [[ -f "$CHAINED/.git/hooks/pre-commit" ]] \
       && grep -q 'git rev-parse --git-dir' "$GHOOKS/pre-commit"; then
      ok "hooksPath chained: install proceeds, stubs in .git/hooks, wrappers untouched"
    else
      nope "hooksPath chained: wrong path taken (see $TMP/out.log)"
    fi
  else
    nope "hooksPath chained: install.sh --repo should exit 0 with valid wrappers"
  fi

  # global hooksPath WITHOUT a pre-push wrapper: block with the culprit named
  GBROKEN="$TMP/ghooks-broken"
  mkdir -p "$GBROKEN"
  cp "$GHOOKS/pre-commit" "$GBROKEN/pre-commit"
  GCFG_BROKEN="$TMP/gitconfig-broken"
  git config --file "$GCFG_BROKEN" core.hooksPath "$GBROKEN"
  BROKEN="$TMP/broken-repo"
  make_repo "$BROKEN"
  if run_install "$GCFG_BROKEN" --repo "$BROKEN"; then
    nope "hooksPath broken: missing pre-push wrapper did NOT block (expected exit 1)"
  else
    if grep -q "chain wrapper(s) missing for: pre-push" "$TMP/out.log"; then
      ok "hooksPath broken: exit 1 and the missing wrapper is named"
    else
      nope "hooksPath broken: exit 1 but the missing wrapper is not named"
    fi
  fi

  # --team: lefthook.yml auto-created by 'lefthook install' must be removed
  # (untracked + default content); config stays in lefthook-local.yml only.
  # excludesFile pre-set in the temp gitconfig so the test never touches the
  # user's real global ignore.
  GCFG_TEAM="$TMP/gitconfig-team"
  git config --file "$GCFG_TEAM" core.excludesFile "$TMP/team-global-ignore"
  TEAMA="$TMP/team-auto"
  make_repo "$TEAMA"
  printf '# EXAMPLE USAGE:\n#\n#   https://lefthook.dev/configuration/\n' > "$TEAMA/lefthook.yml"
  if run_install "$GCFG_TEAM" --repo "$TEAMA" --team; then
    if [[ ! -f "$TEAMA/lefthook.yml" && -f "$TEAMA/lefthook-local.yml" ]] \
       && grep -q "removed lefthook.yml auto-created" "$TMP/out.log"; then
      ok "--team: auto-created (untracked, default) lefthook.yml removed, local yml kept"
    else
      nope "--team: auto-created lefthook.yml survived or removal not reported (see $TMP/out.log)"
    fi
  else
    nope "--team: install exited non-zero on the auto-created-yml fixture"
  fi

  # --team: a TRACKED lefthook.yml belongs to the project -- keep it untouched
  TEAMB="$TMP/team-tracked"
  make_repo "$TEAMB"
  printf 'pre-commit:\n  jobs: []\n' > "$TEAMB/lefthook.yml"
  git -C "$TEAMB" add lefthook.yml
  git -C "$TEAMB" -c user.email=t@t.t -c user.name=t commit -q -m "own lefthook config"
  cp "$TEAMB/lefthook.yml" "$TMP/team-tracked.orig"
  if run_install "$GCFG_TEAM" --repo "$TEAMB" --team; then
    if cmp -s "$TEAMB/lefthook.yml" "$TMP/team-tracked.orig" \
       && grep -q "lefthook-local.yml extends it" "$TMP/out.log"; then
      ok "--team: tracked lefthook.yml untouched, extends-note printed"
    else
      nope "--team: tracked lefthook.yml modified or note missing (see $TMP/out.log)"
    fi
  else
    nope "--team: install exited non-zero on the tracked-yml fixture"
  fi

  # repo-LOCAL core.hooksPath pointing at a TRACKED dir (versioned hooks):
  # stubs must go to .git/hooks and the tracked dir must stay byte-identical
  LOCALHP="$TMP/local-hookspath"
  make_repo "$LOCALHP"
  mkdir -p "$LOCALHP/.githooks"
  printf '#!/bin/sh\n# project-owned hook\nexit 0\n' > "$LOCALHP/.githooks/pre-commit"
  chmod +x "$LOCALHP/.githooks/pre-commit"
  git -C "$LOCALHP" add .githooks
  git -C "$LOCALHP" -c user.email=t@t.t -c user.name=t commit -q -m "versioned hooks"
  git -C "$LOCALHP" config core.hooksPath .githooks
  if run_install "$GCFG_NONE" --repo "$LOCALHP"; then
    if [[ -z "$(git -C "$LOCALHP" status --porcelain -- .githooks)" ]] \
       && grep -q "project-owned hook" "$LOCALHP/.githooks/pre-commit" \
       && [[ -f "$LOCALHP/.git/hooks/pre-commit" ]] \
       && grep -q "local core.hooksPath (.githooks) is tracked" "$TMP/out.log" \
       && grep -q "verified clean" "$TMP/out.log"; then
      ok "local tracked hooksPath: stubs in .git/hooks, .githooks intact and verified clean"
    else
      nope "local tracked hooksPath: tracked dir touched or wrong path taken (see $TMP/out.log)"
    fi
    # wiring honesty: the install must say the stubs are dead code and offer
    # the two exits (delegation PR with the exact snippet, or conscious skip)
    if grep -q "hooks NOT active in this repo" "$TMP/out.log" \
       && grep -q 'lefthook run pre-commit "\$@"' "$TMP/out.log" \
       && grep -q "skip consciously" "$TMP/out.log" \
       && grep -q -- "-- verify: FAIL" "$TMP/out.log" \
       && grep -q "NOT fully active" "$TMP/out.log"; then
      ok "local tracked hooksPath: honest 'hooks NOT active' + both exits + closing verify FAIL"
    else
      nope "local tracked hooksPath: honesty lines or closing verify missing (see $TMP/out.log)"
    fi
  else
    nope "local tracked hooksPath: install exited non-zero"
  fi

  # leaky history: baseline table + grandfathered agent action, and the whole
  # --repo output must be English + plain ASCII (no box-drawing, no Spanish)
  LEAKY="$TMP/leaky-history"
  make_repo "$LEAKY"
  printf 'token = "dpat_%s"\n' "$(printf 'a%.0s' {1..64})" > "$LEAKY/historic.txt"
  git -C "$LEAKY" add historic.txt
  git -C "$LEAKY" -c user.email=t@t.t -c user.name=t commit -q -m "historic leak"
  if run_install "$GCFG_NONE" --repo "$LEAKY"; then
    if grep -q "baseline: 1 findings -- review them once" "$TMP/out.log" \
       && grep -q "Baseline grandfathered 1 historical findings in historic.txt" "$TMP/out.log" \
       && grep -q "Fill the TODOs in the '## ship config' block" "$TMP/out.log"; then
      ok "baseline: findings reported in English + grandfathered agent action with file named"
    else
      nope "baseline: findings/agent action lines missing (see $TMP/out.log)"
    fi
    if ! grep -q "┌" "$TMP/out.log" && ! grep -q "─" "$TMP/out.log" \
       && ! grep -q "hallazgos" "$TMP/out.log" && ! grep -q "bloques" "$TMP/out.log"; then
      ok "--repo output: ASCII-only and English (no ┌/─ box-drawing, no Spanish)"
    else
      nope "--repo output: box-drawing or Spanish strings remain (see $TMP/out.log)"
    fi
  else
    nope "leaky-history: install exited non-zero"
  fi

  # --upgrade: reports both tools + repo freshness, exits 0 or 1, never pulls
  UPGRADE_HEAD_BEFORE="$(git -C "$REPO_DIR" rev-parse HEAD)"
  bash "$INSTALL" --upgrade > "$TMP/out.log" 2> "$TMP/err.log" < /dev/null
  rc=$?
  if [[ "$rc" -le 1 ]] \
     && grep -q "lefthook:" "$TMP/out.log" && grep -q "gitleaks:" "$TMP/out.log" \
     && grep -q "skills repo:" "$TMP/out.log" \
     && [[ "$(git -C "$REPO_DIR" rev-parse HEAD)" == "$UPGRADE_HEAD_BEFORE" ]]; then
    ok "--upgrade: tools + repo freshness reported, exit $rc, no pull performed"
  else
    nope "--upgrade: unexpected output or exit code $rc (see $TMP/out.log)"
  fi
else
  echo "· lefthook/gitleaks not installed — install.sh --repo fixtures skipped (non-fatal)"
fi
