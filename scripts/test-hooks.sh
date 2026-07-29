#!/usr/bin/env bash
# Test harness for the centralized hooks system — thin runner.
#
# The tests live in scripts/tests/, one module per domain, each < 400 lines:
#   00-helpers.sh          shared state ($TMP, counters, ok/nope, fixtures)
#   10-chain.sh            skills symlink chain + FLOW + flowkit link (sync/check/prune)
#   20-lefthook-blocks.sh  run-block extraction + shellcheck of every .sh
#   30-ship-wrapper.sh     ship-config wrapper fixtures + gitleaks config + nudge/commit-msg
#   40-install-repo.sh     install.sh --repo (workspace, hooksPath, --team, baseline, --upgrade)
#   50-harness.sh          Claude Code PreToolUse guards + settings merge
#   60-flowkit.sh          flowkit CLI dispatch, symlink resolution, about, version
#   70-field-feedback.sh   0.1.1 field feedback: --verify, unhook, team portability,
#                          stack templates, baseline context, published-site guard
#   80-brow2-feedback.sh   0.1.3 browv2 feedback: no-block by construction,
#                          git-guard assignment semantics, unhook without
#                          lefthook, about orphan hint, compact output
#
# Modules are sourced here in lexical order, in ONE shell, so they share the
# helpers and accumulate into the same counters. Output contract (consumed by
# the Makefile and habit): final line "test-hooks: N passed, M failed",
# exit 0 = all green, 1 = at least one failure.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$REPO_DIR/scripts/tests"

# shellcheck disable=SC1091  # helpers are shellchecked as their own input
source "$TESTS_DIR/00-helpers.sh"

for module in "$TESTS_DIR"/[1-9]*.sh; do
  # shellcheck disable=SC1090  # modules are enumerated at runtime
  source "$module"
done

# ── verdict ────────────────────────────────────────────────────────────────
echo "──"
echo "test-hooks: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
