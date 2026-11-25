# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/BASE_YML come from 00-helpers.sh via the runner
# shellcheck disable=SC2034  # BLOCKS/WRAPPER are consumed by 30-ship-wrapper.sh
# ── hook scripts: copies for the block tests + shellcheck of every .sh ───

# Each job is a script in .lefthook/<hook>/. The copies get a `set -- <template>`
# line so modules simulate lefthook's args with a sed on the literal template.
extract_blocks() {
  local i=0
  while IFS='|' read -r hook script args; do
    i=$((i + 1))
    awk -v a="$args" '{print} /^set -u$/ && a != "" && !d {print "set -- " a; d=1}' \
      "$REPO_DIR/.lefthook/$hook/$script" \
      | sed "s|^FK_LIB_DIR=.*|FK_LIB_DIR=\"$REPO_DIR/.lefthook/lib\"|" > "$TMP/block$i.sh"
  done < <(awk '
    /^[a-z-]+:$/ { if (s != "") print hook "|" s "|" a; s = ""; hook = substr($0, 1, length($0) - 1) }
    /^ +script:/ { if (s != "") print hook "|" s "|" a; s = $2; a = "" }
    /^ +args:/ { a = $2; gsub(/"/, "", a) }
    END { if (s != "") print hook "|" s "|" a }
  ' "$BASE_YML" | sed 's/^commit-msg|\(.*\)|$/commit-msg|\1|{1}/')
}

extract_blocks
BLOCKS=("$TMP"/block*.sh)
if [[ "${#BLOCKS[@]}" -ge 11 ]]; then
  ok "extracted ${#BLOCKS[@]} hook scripts named by lefthook-base.yml"
else
  nope "expected >= 11 hook scripts, got ${#BLOCKS[@]}"
fi
missing=""
for f in "$REPO_DIR"/.lefthook/*/*.sh; do
  case "$f" in */lib/*) continue ;; esac
  grep -q "script: $(basename "$f")$" "$BASE_YML" || missing="$missing $(basename "$f")"
done
if [[ -z "$missing" ]]; then
  ok "every .lefthook script is wired in lefthook-base.yml"
else
  nope "scripts not wired in lefthook-base.yml:$missing"
fi

WRAPPER="$(grep -l 'lint_cmd' "$TMP"/block*.sh | head -1 || true)"
if [[ -n "$WRAPPER" ]]; then
  ok "pre-push ship-config wrapper located ($(basename "$WRAPPER"))"
else
  nope "pre-push ship-config wrapper not found among extracted blocks"
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  nope "shellcheck not installed (brew install shellcheck)"
else
  for b in "$REPO_DIR"/.lefthook/*/*.sh; do
    if ( cd "$REPO_DIR" && shellcheck -x -s sh "$b" ); then
      ok "shellcheck clean: ${b#"$REPO_DIR"/} (hook script, sh dialect)"
    else
      nope "shellcheck FAILED: ${b#"$REPO_DIR"/}"
    fi
  done
  for s in "$REPO_DIR/bin/flowkit" "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/scripts/lib/*.sh \
           "$REPO_DIR"/scripts/tests/*.sh "$REPO_DIR"/hooks/harness/*.sh; do
    if ( cd "$REPO_DIR" && shellcheck -x "$s" ); then
      ok "shellcheck clean: ${s#"$REPO_DIR"/}"
    else
      nope "shellcheck FAILED: ${s#"$REPO_DIR"/}"
    fi
  done
fi
