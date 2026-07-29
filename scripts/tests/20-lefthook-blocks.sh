# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/BASE_YML come from 00-helpers.sh via the runner
# shellcheck disable=SC2034  # BLOCKS/WRAPPER are consumed by 30-ship-wrapper.sh
# ── lefthook run blocks: extraction + shellcheck of every .sh in the repo ───

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
  for s in "$REPO_DIR/bin/flowkit" "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/scripts/lib/*.sh \
           "$REPO_DIR"/scripts/tests/*.sh "$REPO_DIR"/hooks/harness/*.sh; do
    if shellcheck "$s"; then
      ok "shellcheck clean: ${s#"$REPO_DIR"/}"
    else
      nope "shellcheck FAILED: ${s#"$REPO_DIR"/}"
    fi
  done
fi
