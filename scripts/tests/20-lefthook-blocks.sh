# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/BASE_YML come from 00-helpers.sh via the runner
# shellcheck disable=SC2034  # the script paths are consumed by later modules
# ── hook scripts: paths for the later modules + shellcheck of every .sh ───

# jobs are scripts with real argv: tests call them by path, from a fixture dir
HOOKS="$REPO_DIR/.lefthook"
WRAPPER="$HOOKS/pre-push/ship-config-gate.sh"
NUDGE_SH="$HOOKS/pre-push/docs-nudge.sh"
CMSG_SH="$HOOKS/commit-msg/strip-agent-attribution.sh"
PP_HOOK="$HOOKS/pre-push/gitleaks-pushed.sh"
TN_HOOK="$HOOKS/pre-push/tasks-archive-nudge.sh"
LH_HOOK="$HOOKS/pre-commit/lint-health-staged.sh"
LOCK_HOOK="$HOOKS/pre-commit/lockfile-canary-nudge.sh"
DB_HOOK="$HOOKS/pre-commit/default-branch-nudge.sh"
ENV_HOOK="$HOOKS/pre-commit/block-env-files.sh"
LC_HOOK="$HOOKS/pre-commit/loc-warning.sh"

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
