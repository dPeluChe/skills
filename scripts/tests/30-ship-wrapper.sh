# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/WRAPPER come from earlier modules via the runner
# ── ship-config wrapper fixtures + gitleaks config + nudge/commit-msg blocks ─

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
    if grep -q "no ship config block" "$TMP/err.log"; then
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

# ── gitleaks config sanity (only when gitleaks is available) ────────────────
if command -v gitleaks >/dev/null 2>&1; then
  GLDIR="$TMP/gl-fixture"
  mkdir -p "$GLDIR"
  git -C "$GLDIR" init -q
  # positive: custom rules must fire (fixture strings assembled at runtime so
  # this source file itself never carries a secret-shaped literal)
  {
    printf 'token = "dpat_%s"\n' "$(printf 'a%.0s' {1..64})"
    printf 'ITERIS_SYNC_%s=supersecretvalue123\n' "TOKEN"
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

# ── docs-nudge + commit-msg attribution-strip blocks ────────────────────────
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
