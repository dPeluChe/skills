#!/bin/sh
# shellcheck shell=sh
FK_LIB_DIR="${FK_LIB_DIR:-$(dirname "$0")/../lib}"
# shellcheck source=.lefthook/lib/common.sh
. "$FK_LIB_DIR/common.sh"
set -u
# authorship stays human: strips agent attribution trailers and footers; keeps
# the message intact if stripping would empty it. $1 = the message file.
msg="${1:-}"
[ -n "$msg" ] && [ -f "$msg" ] || exit 0
tmp="$msg.strip"
agents='claude|anthropic|devin|codex|openai|chatgpt|gpt-[0-9]|copilot|cursor|windsurf'
grep -viE "^[[:space:]]*(co-authored-by:.*($agents)|(.*[[:space:]])?generated with[[:space:]]+\[?($agents)|created (by|with)[[:space:]]+\[?($agents))|🤖.*generated with" \
  "$msg" > "$tmp" 2>/dev/null || true
if [ -s "$tmp" ] && ! cmp -s "$tmp" "$msg"; then
  awk '{lines[NR]=$0} END{n=0; for(i=NR;i>0;i--) if(lines[i]!~/^[[:space:]]*$/){n=i;break}; for(i=1;i<=n;i++) print lines[i]}' \
    "$tmp" > "$msg"
fi
rm -f "$tmp"
exit 0
