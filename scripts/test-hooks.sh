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
    for hook in pre-commit pre-push; do
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
if [[ "${#BLOCKS[@]}" -ge 4 ]]; then
  ok "extracted ${#BLOCKS[@]} run blocks from lefthook-base.yml"
else
  nope "expected >= 4 run blocks, got ${#BLOCKS[@]}"
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

# ── verdict ────────────────────────────────────────────────────────────────
echo "──"
echo "test-hooks: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
