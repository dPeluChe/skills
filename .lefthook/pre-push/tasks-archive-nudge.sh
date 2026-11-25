#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# [x] items left in the backlog stop the monthly archive from answering "what was
# built this month". Stdout on purpose: stderr is silenced for the guarded group.
{
  todo=""
  for f in docs/TASK_TODO.md TASK_TODO.md; do
    [ -f "$f" ] && { todo="$f"; break; }
  done
  if [ -n "$todo" ]; then
    n="$(grep -cE '^[[:space:]]*[-*][[:space:]]+\[[xX]\]' "$todo" 2>/dev/null || true)"
    if [ "${n:-0}" -gt 0 ]; then
      echo "[hooks] $n completed task(s) still in $todo -- run: /pm-tasks archive"
      echo "[hooks]   (they belong in docs/TASK_COMPLETED/YYMM.md; the monthly file"
      echo "[hooks]    answers 'what was built this month'. Does not block.)"
    fi
  fi
} 2>/dev/null || true
exit 0
