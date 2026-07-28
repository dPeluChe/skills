#!/usr/bin/env bash
# Test harness for the centralized hooks system.
#
# 1. Extracts every multiline `run: |` block from hooks/lefthook-base.yml
#    (yq when available, awk fallback) and shellchecks each one as POSIX sh.
# 2. Shellchecks scripts/install.sh and this file.
# 3. Runs the pre-push wrapper against two CLAUDE.md fixtures:
#    a repo WITH a valid "## ship config" block (must extract and run the
#    commands) and a repo WITHOUT one (must warn loudly and pass, exit 0).
# 4. If gitleaks is installed, validates hooks/.gitleaks.toml against
#    positive/negative secret fixtures.
# 5. Runs the pre-push docs-nudge and commit-msg attribution-strip blocks
#    against fixtures.
# 6. If lefthook + gitleaks are installed, exercises install.sh --repo against
#    workspace and global-hooksPath fixtures, and install.sh --upgrade.
#
# Exit 0 = all green, 1 = at least one failure.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_YML="$REPO_DIR/hooks/lefthook-base.yml"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { echo "✓ $*"; PASS=$((PASS + 1)); }
nope() { echo "✗ $*"; FAIL=$((FAIL + 1)); }

# ── 1. extract run blocks ──────────────────────────────────────────────────
extract_blocks() {
  if command -v yq >/dev/null 2>&1; then
    local i=0 hook job n
    for hook in pre-commit pre-push commit-msg; do
      n="$(yq ".\"$hook\".jobs | length" "$BASE_YML")"
      for ((job = 0; job < n; job++)); do
        i=$((i + 1))
        yq -r ".\"$hook\".jobs[$job].run" "$BASE_YML" > "$TMP/block$i.sh"
      done
    done
  else
    awk -v out="$TMP/block" '
      /run: \|/ { n++; f = out n ".sh"; match($0, /^ */); base = RLENGTH; strip = 0; grab = 1; next }
      grab {
        if ($0 ~ /^ *$/) { print "" > f; next }
        match($0, /^ */); ind = RLENGTH
        if (ind <= base) { grab = 0; close(f); next }
        if (!strip) strip = ind
        print substr($0, strip + 1) > f
      }
    ' "$BASE_YML"
  fi
}

extract_blocks
BLOCKS=("$TMP"/block*.sh)
if [[ "${#BLOCKS[@]}" -ge 6 ]]; then
  ok "extracted ${#BLOCKS[@]} run blocks from lefthook-base.yml"
else
  nope "expected >= 6 run blocks, got ${#BLOCKS[@]}"
fi

WRAPPER="$(grep -l 'ship config' "$TMP"/block*.sh | head -1 || true)"
if [[ -n "$WRAPPER" ]]; then
  ok "pre-push ship-config wrapper located ($(basename "$WRAPPER"))"
else
  nope "pre-push ship-config wrapper not found among extracted blocks"
fi

# ── 2. shellcheck ──────────────────────────────────────────────────────────
if ! command -v shellcheck >/dev/null 2>&1; then
  nope "shellcheck not installed (brew install shellcheck)"
else
  for b in "${BLOCKS[@]}"; do
    if shellcheck -s sh "$b"; then
      ok "shellcheck clean: $(basename "$b") (lefthook run block, sh dialect)"
    else
      nope "shellcheck FAILED: $(basename "$b")"
    fi
  done
  for s in "$REPO_DIR/scripts/install.sh" "$REPO_DIR/scripts/test-hooks.sh"; do
    if shellcheck "$s"; then
      ok "shellcheck clean: ${s#"$REPO_DIR"/}"
    else
      nope "shellcheck FAILED: ${s#"$REPO_DIR"/}"
    fi
  done
fi

# ── 3. wrapper behavior against CLAUDE.md fixtures ─────────────────────────
run_wrapper() { # $1 = fixture repo dir, $2 = simulated {push_files}
  local dir="$1" files="$2" script="$TMP/wrapper-run.sh"
  sed "s|{push_files}|$files|" "$WRAPPER" > "$script"
  ( cd "$dir" && sh "$script" ) > "$TMP/out.log" 2> "$TMP/err.log"
}

make_fixture() { # $1 = dir; CLAUDE.md content on stdin
  mkdir -p "$1"
  git -C "$1" init -q
  cat > "$1/CLAUDE.md"
}

if [[ -n "$WRAPPER" ]]; then
  # fixture A: valid "## ship config" block — commands must be extracted and run
  MARKER="$TMP/marker.txt"
  export MARKER
  make_fixture "$TMP/fix-valid" <<EOF
# Test repo

## ship config

\`\`\`yaml
lint: echo LINT-OK >> "\$MARKER"
typecheck: echo TYPECHECK-OK >> "\$MARKER"
loc_limit: 500
\`\`\`

## another section
EOF
  : > "$MARKER"
  if run_wrapper "$TMP/fix-valid" "src/app.ts src/lib.ts"; then
    if grep -q "LINT-OK" "$MARKER" && grep -q "TYPECHECK-OK" "$MARKER"; then
      ok "fixture A: ship config parsed, lint + typecheck executed, exit 0"
    else
      nope "fixture A: exit 0 but commands did not run (marker: $(cat "$MARKER"))"
    fi
  else
    nope "fixture A: wrapper exited non-zero on a valid ship config"
  fi

  # fixture A2: failing lint must block the push (exit 1)
  make_fixture "$TMP/fix-failing" <<'EOF'
# Test repo

## ship config

```yaml
lint: false
```
EOF
  if run_wrapper "$TMP/fix-failing" "src/app.ts"; then
    nope "fixture A2: failing lint did NOT block (expected exit 1)"
  else
    ok "fixture A2: failing lint blocks the push (exit 1)"
  fi

  # fixture B: no ship config block — fail-soft, loud warning, exit 0
  make_fixture "$TMP/fix-none" <<'EOF'
# Test repo — no ship config here
EOF
  if run_wrapper "$TMP/fix-none" "src/app.ts"; then
    if grep -q "repo sin ship config" "$TMP/err.log"; then
      ok "fixture B: no block → fail-soft warning + exit 0"
    else
      nope "fixture B: exit 0 but the loud warning is missing"
    fi
  else
    nope "fixture B: wrapper blocked a repo without ship config (must fail-soft)"
  fi

  # skip: docs-only push never runs lint
  if run_wrapper "$TMP/fix-failing" "README.md docs/GUIDE.md"; then
    ok "skip: docs-only push exits 0 without running lint"
  else
    nope "skip: docs-only push should exit 0"
  fi

  # skip: empty push (branch deletion / tag move) is a total skip
  if run_wrapper "$TMP/fix-failing" ""; then
    ok "skip: empty push_files (deletion/tag move) exits 0"
  else
    nope "skip: empty push_files should exit 0"
  fi
fi

# ── 4. gitleaks config sanity (only when gitleaks is available) ────────────
if command -v gitleaks >/dev/null 2>&1; then
  GLDIR="$TMP/gl-fixture"
  mkdir -p "$GLDIR"
  git -C "$GLDIR" init -q
  # positive: custom rules must fire
  {
    printf 'token = "dpat_%s"\n' "$(printf 'a%.0s' {1..64})"
    printf 'ITERIS_SYNC_TOKEN=supersecretvalue123\n'
  } > "$GLDIR/leaky.txt"
  if gitleaks dir "$GLDIR" --config "$REPO_DIR/hooks/.gitleaks.toml" \
      --no-banner --redact >/dev/null 2>&1; then
    nope "gitleaks: custom rules did NOT flag known-bad fixtures"
  else
    ok "gitleaks: custom rules flag dpat_/ITERIS_SYNC_TOKEN fixtures"
  fi
  # negative: documented placeholder must be allowlisted
  rm -f "$GLDIR/leaky.txt"
  printf 'Use your token: dpat_<your-token-here>\n' > "$GLDIR/README-example.txt"
  if gitleaks dir "$GLDIR" --config "$REPO_DIR/hooks/.gitleaks.toml" \
      --no-banner --redact >/dev/null 2>&1; then
    ok "gitleaks: placeholder examples pass the allowlist"
  else
    nope "gitleaks: placeholder example was flagged (allowlist broken)"
  fi
else
  echo "· gitleaks not installed — config fixtures skipped (non-fatal)"
fi

# ── 5. docs-nudge + commit-msg attribution-strip blocks ────────────────────
run_block() { # $1 = block file, $2 = fixture dir, $3 = simulated {push_files}
  local script="$TMP/run-one-block.sh"
  sed "s|{push_files}|$3|" "$1" > "$script"
  ( cd "$2" && sh "$script" ) > "$TMP/out.log" 2> "$TMP/err.log"
}

NUDGE="$(grep -l 'no docs touched' "$TMP"/block*.sh | head -1 || true)"
if [[ -n "$NUDGE" ]]; then
  ok "pre-push docs-nudge block located ($(basename "$NUDGE"))"
  mkdir -p "$TMP/nudge-fix"
  if run_block "$NUDGE" "$TMP/nudge-fix" "src/app.ts convex/schema.ts" \
     && grep -q "no docs touched" "$TMP/err.log"; then
    ok "docs-nudge: code-only push prints the reminder, exit 0"
  else
    nope "docs-nudge: code-only push should warn and exit 0"
  fi
  if run_block "$NUDGE" "$TMP/nudge-fix" "src/app.ts docs/GUIDE.md" \
     && ! grep -q "no docs touched" "$TMP/err.log"; then
    ok "docs-nudge: push touching .md stays silent"
  else
    nope "docs-nudge: push with docs should not warn"
  fi
  if run_block "$NUDGE" "$TMP/nudge-fix" "notes.txt Makefile" \
     && ! grep -q "no docs touched" "$TMP/err.log"; then
    ok "docs-nudge: non-code push stays silent"
  else
    nope "docs-nudge: non-code push should not warn"
  fi
else
  nope "pre-push docs-nudge block not found among extracted blocks"
fi

CMSG="$(grep -l 'co-authored-by' "$TMP"/block*.sh | head -1 || true)"
run_cmsg() { # $1 = commit message file
  local script="$TMP/cmsg-run.sh"
  sed "s|{1}|$1|" "$CMSG" > "$script"
  sh "$script" > "$TMP/out.log" 2> "$TMP/err.log"
}
if [[ -n "$CMSG" ]]; then
  ok "commit-msg attribution-strip block located ($(basename "$CMSG"))"

  # agent trailers stripped, human co-author and body preserved
  cat > "$TMP/msg-agent.txt" <<'EOF'
feat: add thing

Body line stays.

Co-authored-by: Jane Dev <jane@example.com>
Co-Authored-By: Claude <noreply@anthropic.com>
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
  if run_cmsg "$TMP/msg-agent.txt" \
     && ! grep -qi 'claude' "$TMP/msg-agent.txt" \
     && ! grep -q '🤖' "$TMP/msg-agent.txt" \
     && grep -q 'feat: add thing' "$TMP/msg-agent.txt" \
     && grep -q 'Jane Dev' "$TMP/msg-agent.txt" \
     && [[ "$(tail -1 "$TMP/msg-agent.txt")" == *"Jane Dev"* ]]; then
    ok "commit-msg: agent trailers stripped, human content intact, no trailing blanks"
  else
    nope "commit-msg: strip failed (result: $(cat "$TMP/msg-agent.txt"))"
  fi

  # normal message untouched
  printf 'fix: plain message\n\nNothing to strip here.\n' > "$TMP/msg-clean.txt"
  cp "$TMP/msg-clean.txt" "$TMP/msg-clean.orig"
  if run_cmsg "$TMP/msg-clean.txt" && cmp -s "$TMP/msg-clean.txt" "$TMP/msg-clean.orig"; then
    ok "commit-msg: clean message passes byte-identical"
  else
    nope "commit-msg: clean message was modified"
  fi

  # message that is ONLY attribution: keep original rather than empty it
  printf 'Co-authored-by: Claude <noreply@anthropic.com>\n' > "$TMP/msg-only.txt"
  cp "$TMP/msg-only.txt" "$TMP/msg-only.orig"
  if run_cmsg "$TMP/msg-only.txt" && cmp -s "$TMP/msg-only.txt" "$TMP/msg-only.orig"; then
    ok "commit-msg: all-attribution message kept (never emptied)"
  else
    nope "commit-msg: all-attribution message was emptied or altered"
  fi
else
  nope "commit-msg attribution-strip block not found among extracted blocks"
fi

# ── 6. install.sh --repo: workspace mode, global hooksPath, --upgrade ──────
INSTALL="$REPO_DIR/scripts/install.sh"
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

  make_repo() { # $1 = dir — git repo with one commit
    mkdir -p "$1"
    git -C "$1" init -q
    git -C "$1" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m init
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
    if grep -q "2 bloques de código en CLAUDE.md/AGENTS.md" "$TMP/out.log"; then
      ok "agent-docs fences: 2 extra fences counted, /doctos recommended, exit 0"
    else
      nope "agent-docs fences: fence count/notice missing (see $TMP/out.log)"
    fi
  else
    nope "agent-docs fences: detection must never block the install"
  fi

  CLEANDOC="$TMP/cleandoc"
  make_repo "$CLEANDOC"
  cat > "$CLEANDOC/CLAUDE.md" <<'EOF'
# Test repo

## ship config

```yaml
lint: true
```
EOF
  if run_install "$GCFG_NONE" --repo "$CLEANDOC" \
     && ! grep -q "bloques de código" "$TMP/out.log"; then
    ok "agent-docs fences: ship config yaml fence alone stays silent"
  else
    nope "agent-docs fences: false positive on the canonical ship config fence"
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

# ── verdict ────────────────────────────────────────────────────────────────
echo "──"
echo "test-hooks: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
