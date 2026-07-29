#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Bash) — blocks destructive git before it runs.
# stdin: hook JSON ({.tool_input.command}); exit 2 + stderr = block, the model
# reads the reason. Escape hatch: FLOWKIT_GIT_GUARD=off passes with a warning.
set -uo pipefail

RAW="$(cat 2>/dev/null || true)"
[[ -n "$RAW" ]] || exit 0

if command -v jq >/dev/null 2>&1; then
  CMD="$(printf '%s' "$RAW" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
else
  CMD="$(printf '%s' "$RAW" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    pass
' 2>/dev/null || true)"
fi
[[ -n "${CMD:-}" ]] || exit 0

# Bypass vars count only in ASSIGNMENT POSITION: at a command start (^ ; & |
# parens), optionally behind env/export or other leading VAR=val words. A
# prose mention (PR body, echo, docs) is data, not an assignment — it never
# triggers the guard.
# assignment position includes after do/then/else/{ so the escape hatch works
# inside loops and conditionals -- the documented remedy must work where the
# need is (deleting N branches in a loop is THE use case)
re_assign_pre='(^|[;&|({]|[[:space:]](do|then|else)[[:space:]])[[:space:]]*((env|export)[[:space:]]+)?([A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]]+)*'
re_lefthook0=${re_assign_pre}'LEFTHOOK='
re_guard_off=${re_assign_pre}'FLOWKIT_GIT_GUARD=off([[:space:]]|$)'

# Not a git command and no hook-bypass assignment -> silent pass
re_has_git='(^|[^[:alnum:]_./-])git([[:space:]]|$)'
if ! [[ "$CMD" =~ $re_has_git || "$CMD" =~ $re_lefthook0 ]]; then
  exit 0
fi

# escape hatch: honored from the hook's env OR assigned on the command itself
if [[ "${FLOWKIT_GIT_GUARD:-}" == "off" || "$CMD" =~ $re_guard_off ]]; then
  echo "[git-guard] FLOWKIT_GIT_GUARD=off — destructive-git protection disabled for this command" >&2
  exit 0
fi

block() { # $1 = what matched, $2 = guidance
  {
    echo "[git-guard] blocked: $1"
    echo "Command: $CMD"
    echo "$2"
    echo "If a human explicitly approved this exact command, re-run it with FLOWKIT_GIT_GUARD=off."
  } >&2
  exit 2
}

# 'git' + optional global flags (-c k=v, -C dir, --flag[=v], -shorts) + subcommand
G='(^|[;&|[:space:]()])git([[:space:]]+(-[cC][[:space:]]+[^[:space:]]+|--[^[:space:]]+|-[[:alnum:]]+))*[[:space:]]+'

# ── our hook bypasses first: they defeat every other guard ─────────────────
[[ "$CMD" =~ $re_lefthook0 ]] && block "LEFTHOOK= assignment (hook bypass)" \
  "Do not disable lefthook; let the hooks run and fix what they flag."
re_no_verify=${G}'[^;&|]*--no-verify'
[[ "$CMD" =~ $re_no_verify ]] && block "--no-verify (hook bypass)" \
  "Do not skip commit/push hooks; let them run and fix what they flag."

# ── destructive git ────────────────────────────────────────────────────────
# --force-with-lease is the sanctioned alternative: strip it before probing
PROBE="${CMD//--force-with-lease/}"
re_force_push=${G}'push[^;&|]*[[:space:]](-[[:alnum:]]*f|--force)([[:space:]]|$)'
[[ "$PROBE" =~ $re_force_push ]] && block "git push --force" \
  "Use --force-with-lease if the remote truly needs rewriting."

re_reset_hard=${G}'reset[^;&|]*--hard'
[[ "$CMD" =~ $re_reset_hard ]] && block "git reset --hard" \
  "Use 'git stash' or 'git restore' on specific paths instead of nuking the tree."

re_clean=${G}'clean[^;&|]*[[:space:]](-[[:alnum:]]*f[[:alnum:]]*|--force)([[:space:]]|$)'
[[ "$CMD" =~ $re_clean ]] && block "git clean -f" \
  "Untracked files would be deleted irreversibly. List them first with 'git clean -n'."

re_branch_D=${G}'branch[^;&|]*[[:space:]]-D([[:space:]]|$)'
[[ "$CMD" =~ $re_branch_D ]] && block "git branch -D" \
  "Use 'git branch -d' so unmerged work is never dropped silently."

re_filter_branch=${G}'filter-branch([[:space:]]|$)'
[[ "$CMD" =~ $re_filter_branch ]] && block "git filter-branch" \
  "History rewriting is out of scope for agents; a human runs this deliberately."

re_stash_drop=${G}'stash[[:space:]]+(drop|clear)([[:space:]]|$)'
[[ "$CMD" =~ $re_stash_drop ]] && block "git stash drop/clear" \
  "Stashed work would be lost. Inspect it first with 'git stash list' / 'git stash show'."

re_checkout_dot=${G}'checkout[[:space:]]+(--[[:space:]]+)?\.([[:space:]]*$|[[:space:]]*[;&|])'
[[ "$CMD" =~ $re_checkout_dot ]] && block "git checkout -- . (whole tree discard)" \
  "Discard specific paths instead: 'git restore <file>'."

re_update_ref=${G}'update-ref[[:space:]]+(-d|--delete)([[:space:]]|$)'
[[ "$CMD" =~ $re_update_ref ]] && block "git update-ref -d" \
  "Deleting refs by hand loses history anchors; a human runs this deliberately."

exit 0
