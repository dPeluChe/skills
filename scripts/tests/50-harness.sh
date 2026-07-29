# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR come from 00-helpers.sh via the runner
# ── Claude Code harness hooks: git-guard, secret-guard, settings merge ──────

GG="$REPO_DIR/hooks/harness/git-guard.sh"
SG="$REPO_DIR/hooks/harness/secret-guard.sh"

bash_hook_json() { # $1 = shell command → PreToolUse(Bash) JSON on stdout
  python3 -c 'import json,sys;print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"
}
run_gg() { bash_hook_json "$1" | bash "$GG" > "$TMP/out.log" 2> "$TMP/err.log"; }

if [[ -x "$GG" ]]; then
  ok "git-guard present and executable"

  GG_BLOCK=(
    "git push --force origin main"
    "git push -f"
    "git reset --hard HEAD~3"
    "git clean -fd"
    "git branch -D feature-x"
    "git stash drop"
    "git checkout -- ."
    "git update-ref -d refs/heads/x"
    "git filter-branch --tree-filter true HEAD"
    "git commit --no-verify -m wip"
    "LEFTHOOK=0 git commit -m wip"
  )
  gg_bad=0
  for cmd in "${GG_BLOCK[@]}"; do
    run_gg "$cmd"; rc=$?
    if [[ "$rc" -ne 2 || ! -s "$TMP/err.log" ]]; then
      nope "git-guard: NOT blocked (rc=$rc): $cmd"
      gg_bad=1
    fi
  done
  [[ "$gg_bad" -eq 0 ]] && ok "git-guard: ${#GG_BLOCK[@]} destructive/bypass commands block with exit 2 + stderr"

  GG_PASS=(
    "git push --force-with-lease origin main"
    "git push origin main"
    "git status"
    "git checkout -- src/app.ts"
    "ls -la"
    "npm run build --force"
  )
  gg_bad=0
  for cmd in "${GG_PASS[@]}"; do
    if ! run_gg "$cmd" || [[ -s "$TMP/err.log" ]]; then
      nope "git-guard: safe command did not pass silently: $cmd"
      gg_bad=1
    fi
  done
  [[ "$gg_bad" -eq 0 ]] && ok "git-guard: ${#GG_PASS[@]} safe/non-git commands pass silently (exit 0)"

  if bash_hook_json "git push --force origin main" \
       | FLOWKIT_GIT_GUARD=off bash "$GG" > "$TMP/out.log" 2> "$TMP/err.log" \
     && grep -q "FLOWKIT_GIT_GUARD=off" "$TMP/err.log"; then
    ok "git-guard: FLOWKIT_GIT_GUARD=off escape hatch passes with a warning"
  else
    nope "git-guard: escape hatch should exit 0 and warn on stderr"
  fi
else
  nope "hooks/harness/git-guard.sh missing or not executable"
fi

write_hook_json() { # $1 = file_path, $2 = content → PreToolUse(Write) JSON
  python3 -c 'import json,sys;print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$1" "$2"
}
edit_hook_json() { # $1 = file_path, $2 = new_string → PreToolUse(Edit) JSON
  python3 -c 'import json,sys;print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"new_string":sys.argv[2]}}))' "$1" "$2"
}
run_sg() { bash "$SG" > "$TMP/out.log" 2> "$TMP/err.log"; }

if [[ -x "$SG" ]]; then
  ok "secret-guard present and executable"
  # secret-shaped fixtures assembled at runtime so this source file itself
  # never carries a literal the guards (or gitleaks) would flag
  FAKE_DPAT="dpat_$(printf 'a%.0s' {1..64})"
  FAKE_AKIA="AKIA$(printf 'ABCDEFGHIJKLMNOP')"

  write_hook_json "config.js" "const token = \"$FAKE_DPAT\";" | run_sg; rc=$?
  if [[ "$rc" -eq 2 ]] && grep -q "secret detected (rule" "$TMP/err.log"; then
    ok "secret-guard: real-shaped dpat_ in content blocks with rule named"
  else
    nope "secret-guard: dpat content should block with exit 2 (rc=$rc)"
  fi

  edit_hook_json "deploy.py" "key = '$FAKE_AKIA'" | run_sg; rc=$?
  if [[ "$rc" -eq 2 ]] && grep -q "secret detected (rule" "$TMP/err.log"; then
    ok "secret-guard: AKIA key in new_string (Edit) blocks"
  else
    nope "secret-guard: AKIA new_string should block with exit 2 (rc=$rc)"
  fi

  if write_hook_json "README.md" "Use your token: dpat_<your-token-here>" | run_sg; then
    ok "secret-guard: documented placeholder passes the allowlist"
  else
    nope "secret-guard: placeholder dpat_<...> was flagged (allowlist broken)"
  fi

  if write_hook_json "src/app.ts" "export const answer = 42;" | run_sg; then
    ok "secret-guard: clean content passes"
  else
    nope "secret-guard: clean content should pass"
  fi

  write_hook_json ".env" "FOO=bar" | run_sg; rc=$?
  if [[ "$rc" -eq 2 ]] && grep -q "\.env" "$TMP/err.log"; then
    ok "secret-guard: .env file_path blocks outright"
  else
    nope "secret-guard: .env path should block (rc=$rc)"
  fi

  write_hook_json "apps/web/.env.local" "FOO=bar" | run_sg; rc=$?
  if [[ "$rc" -eq 2 ]]; then
    ok "secret-guard: nested .env.local blocks too"
  else
    nope "secret-guard: nested .env.local should block (rc=$rc)"
  fi

  if write_hook_json ".env.example" "API_KEY=your-key-here" | run_sg; then
    ok "secret-guard: .env.example with placeholders passes"
  else
    nope "secret-guard: .env.example should pass"
  fi

  # fallback net: run with a PATH that has python3 but no gitleaks/jq
  run_sg_fb() { env PATH=/usr/bin:/bin /bin/bash "$SG" > "$TMP/out.log" 2> "$TMP/err.log"; }
  if env PATH=/usr/bin:/bin /usr/bin/python3 -c '' 2>/dev/null; then
    write_hook_json "config.js" "const token = \"$FAKE_DPAT\";" | run_sg_fb; rc=$?
    if [[ "$rc" -eq 2 ]] && grep -q "secret detected (rule" "$TMP/err.log"; then
      ok "secret-guard fallback (no gitleaks in PATH): dpat content still blocks"
    else
      nope "secret-guard fallback: dpat content should block (rc=$rc)"
    fi
    if write_hook_json "README.md" "Use your token: dpat_<your-token-here>" | run_sg_fb \
       && write_hook_json "src/app.ts" "export const answer = 42;" | run_sg_fb; then
      ok "secret-guard fallback: placeholder + clean content pass"
    else
      nope "secret-guard fallback: placeholder/clean content should pass"
    fi
  else
    echo "· /usr/bin/python3 unavailable — secret-guard fallback fixtures skipped (non-fatal)"
  fi
else
  nope "hooks/harness/secret-guard.sh missing or not executable"
fi

# install.sh --harness: settings merge is idempotent and preserves the JSON
HARNESS_TMP="$TMP/harness"
mkdir -p "$HARNESS_TMP"
H_SETTINGS="$HARNESS_TMP/settings.json"
cat > "$H_SETTINGS" <<'EOF'
{
  "model": "opus",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "echo done" }] }
    ]
  }
}
EOF
run_harness_install() {
  AGENTS_HOOKS_DIR="$HARNESS_TMP/hooks-harness" CLAUDE_SETTINGS_FILE="$H_SETTINGS" \
    bash "$REPO_DIR/scripts/install.sh" --harness > "$TMP/out.log" 2> "$TMP/err.log"
}
if run_harness_install; then
# shellcheck disable=SC2016  # $HOME is a literal in the merged settings command
  merged_ok="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
pre = d.get("hooks", {}).get("PreToolUse", [])
cmds = [h.get("command") for e in pre for h in e.get("hooks", [])]
matchers = [e.get("matcher") for e in pre]
ok = (
    d.get("model") == "opus"
    and "PostToolUse" in d.get("hooks", {})
    and "Bash" in matchers and "Edit|Write" in matchers
    and "$HOME/.agents/hooks-harness/git-guard.sh" in cmds
    and "$HOME/.agents/hooks-harness/secret-guard.sh" in cmds
)
print("yes" if ok else "no")
' "$H_SETTINGS")"
  if [[ "$merged_ok" == "yes" ]] \
     && [[ "$(readlink "$HARNESS_TMP/hooks-harness")" == "$REPO_DIR/hooks/harness" ]] \
     && [[ -f "$H_SETTINGS.bak" ]]; then
    ok "--harness: symlink + both guards merged, existing settings preserved, .bak written"
  else
    nope "--harness: merge/link/backup incomplete (see $H_SETTINGS)"
  fi
  cp "$H_SETTINGS" "$TMP/harness-run1.json"
  if run_harness_install && cmp -s "$H_SETTINGS" "$TMP/harness-run1.json" \
     && grep -q "already there" "$TMP/out.log"; then
    ok "--harness: second run is a no-op (idempotent merge)"
  else
    nope "--harness: second run changed settings.json or did not report 'already there'"
  fi
  if AGENTS_HOOKS_DIR="$HARNESS_TMP/hooks-harness" CLAUDE_SETTINGS_FILE="$H_SETTINGS" \
       AGENTS_SKILLS_DIR="$TMP/h-agents" CLAUDE_SKILLS_DIR="$TMP/h-claude" \
       FLOWKIT_BIN_DIR="$TMP/h-bin" bash "$REPO_DIR/scripts/install.sh" --check \
       > "$TMP/out.log" 2>&1; grep -q "ok harness hooks" "$TMP/out.log"; then
    ok "--check: validates harness link + settings entries once installed"
  else
    nope "--check: harness validation line missing (see $TMP/out.log)"
  fi
else
  nope "--harness: install exited non-zero (see $TMP/err.log)"
fi
