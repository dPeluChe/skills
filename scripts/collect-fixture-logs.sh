#!/usr/bin/env bash
# Collect the test suite's per-fixture logs into one directory for upload.
#
# install.sh and verify write their real detail into per-fixture logs under the
# suite's $TMP; the console shows only the assertion line. A red run that keeps
# no fixtures is undiagnosable after the fact, which is how a flake survived in
# main for months (docs/FEATURES/CANARY_DETERMINISM.md). Both CI jobs call this
# so the file filter cannot drift between them.
#
# Usage: scripts/collect-fixture-logs.sh <suite-output-file> <destination-dir>
set -uo pipefail

suite_out="${1:?usage: collect-fixture-logs.sh <suite.out> <dst>}"
dst="${2:?usage: collect-fixture-logs.sh <suite.out> <dst>}"

mkdir -p "$dst"
# the suite prints "[keep-tmp] TMP=<path>" once (00-helpers.sh)
base="$(grep '\[keep-tmp\] TMP=' "$suite_out" 2>/dev/null | sed 's/.*TMP=//' | head -1)"

if [ -n "$base" ] && [ -d "$base" ]; then
  find "$base" -type f \( -name '*.log' -o -name '*.tsv' -o -name '*.json' \
    -o -name 'lefthook*.yml' -o -name '.gitleaks*.toml' -o -name 'CLAUDE.md' -o -name 'CLAUDE.local.md' \) \
    -print0 2>/dev/null \
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
