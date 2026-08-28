#!/usr/bin/env bash
# Collect the test suite's per-fixture logs into one directory for upload.
#
# Fixture retention policy lives in scripts/tests/00-helpers.sh; this only copies
# what a failed run left behind. Both CI jobs call it so the filter cannot drift.
#
# Usage: scripts/collect-fixture-logs.sh <suite-output-file> <destination-dir>
set -uo pipefail

suite_out="${1:?usage: collect-fixture-logs.sh <suite.out> <dst>}"
dst="${2:?usage: collect-fixture-logs.sh <suite.out> <dst>}"

mkdir -p "$dst"
# the suite prints "[keep-tmp] TMP=<path>" once (00-helpers.sh)
base="$(grep '\[keep-tmp\] TMP=' "$suite_out" 2>/dev/null | sed 's/.*TMP=//' | head -1)"

if [ -n "$base" ] && [ -d "$base" ]; then
  # take everything small rather than an allow-list: on a failure-only path
  # completeness beats artifact size, and a pattern nobody remembered to add is
  # exactly the "red run with no evidence" this script exists to prevent. The
  # list had already grown 4 -> 7 patterns while still missing the extensionless
  # hook stubs, the evidence for the largest failure class here.
  find "$base" -type d -name objects -prune -o -type f -size -128k -print0 2>/dev/null \
    | while IFS= read -r -d '' f; do
        rel="${f#"$base"/}"
        mkdir -p "$dst/$(dirname "$rel")"
        cp "$f" "$dst/$rel" 2>/dev/null || true
      done
else
  echo "no fixture dir found (suite may have wiped it: green run without FLOWKIT_KEEP_TMP)"
fi

cp "$suite_out" "$dst/suite.out" 2>/dev/null || true
echo "collected file count: $(find "$dst" -type f 2>/dev/null | wc -l | tr -d ' ')"
