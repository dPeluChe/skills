# shellcheck shell=bash
# shellcheck disable=SC2154  # REPO_DIR/TMP come from the runner
# ── Claude Code's own plugin validator, on tracked files only (local: CI has no claude CLI) ──
if ! command -v claude >/dev/null 2>&1; then
  echo "· claude CLI not installed -- plugin validate skipped (non-fatal)"
else
  # a copy of tracked files only: local .DS_Store and scratch files are not what ships
  PV="$TMP/plugin-validate"; mkdir -p "$PV"
  (cd "$REPO_DIR" && git ls-files | tar -cf - -T - | tar -xf - -C "$PV")
  if claude plugin validate "$PV" --json > "$PV.json" 2>/dev/null; then
    # allowed by design: the root CLAUDE.md is this repo's dev guide, and no version field so
    # installs update on every commit (a pinned version only updates when the string changes)
    extra="$(jq -r '[.manifest.warnings[]?, .contents[]?.warnings[]?]
      | map(select(.path != "root" and (.path | test("version$")) == false)) | .[].message' "$PV.json")"
    if [[ -z "$extra" ]]; then ok "plugin validate: no errors, no unexpected warnings"
    else nope "plugin validate: unexpected warnings: $(tr '\n' ';' <<<"$extra")"; fi
  else
    nope "plugin validate: failed: $(jq -c '[.. | objects | select(has("errors")) | .errors[]?]' "$PV.json" 2>/dev/null)"
  fi
fi
