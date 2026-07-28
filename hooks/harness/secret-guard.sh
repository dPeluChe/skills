#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Edit|Write) — blocks writing secrets.
# stdin: hook JSON; scans .tool_input.content / .new_string with gitleaks
# (hooks/.gitleaks.toml, resolved relative to this script) or a regex fallback.
# .env* file_path targets (except .env.example/.env.sample) block outright.
# exit 2 + stderr = block, the model reads the reason.
set -uo pipefail

# pwd -P resolves the ~/.agents/hooks-harness directory symlink to the repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG="$SCRIPT_DIR/../.gitleaks.toml"

RAW="$(cat 2>/dev/null || true)"
[[ -n "$RAW" ]] || exit 0

REPORT=""
TMP_CONTENT="$(mktemp)"
trap 'rm -f "$TMP_CONTENT" "${REPORT:-}"' EXIT

# extract file_path (stdout) + content/new_string (into $TMP_CONTENT)
FILE_PATH="$(printf '%s' "$RAW" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input", {})
parts = [ti[k] for k in ("content", "new_string") if isinstance(ti.get(k), str) and ti[k]]
with open(sys.argv[1], "w") as f:
    f.write("\n".join(parts))
print(ti.get("file_path", ""))
' "$TMP_CONTENT" 2>/dev/null || true)"

if [[ -z "$FILE_PATH" && ! -s "$TMP_CONTENT" ]] && command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$RAW" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  printf '%s' "$RAW" \
    | jq -r '[.tool_input.content // empty, .tool_input.new_string // empty] | map(select(. != "")) | join("\n")' \
    > "$TMP_CONTENT" 2>/dev/null || true
fi

# ── .env* targets: never written by agents ─────────────────────────────────
base="$(basename "${FILE_PATH:-x}")"
case "$base" in
  .env | .env.*)
    if [[ "$base" != ".env.example" && "$base" != ".env.sample" ]]; then
      echo "[secret-guard] blocked: writing to $FILE_PATH — agents never write .env files; put placeholders in .env.example and let a human fill the real one" >&2
      exit 2
    fi
    ;;
esac

[[ -s "$TMP_CONTENT" ]] || exit 0

deny() { # $1 = rule id
  echo "[secret-guard] secret detected (rule $1) — do not write secrets to files; use env/config references (process.env.X, os.environ) and keep real values out of the repo" >&2
  exit 2
}

# ── primary: gitleaks with the repo config ─────────────────────────────────
if command -v gitleaks >/dev/null 2>&1 && [[ -f "$CONFIG" ]]; then
  REPORT="$(mktemp)"
  gitleaks stdin --config "$CONFIG" --no-banner --redact --exit-code 99 \
    --report-format json --report-path "$REPORT" < "$TMP_CONTENT" >/dev/null 2>&1
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    exit 0
  elif [[ "$rc" -eq 99 ]]; then
    rule="$(python3 -c '
import json, sys
try:
    findings = json.load(open(sys.argv[1]))
    print(findings[0].get("RuleID", "unknown") if findings else "unknown")
except Exception:
    print("unknown")
' "$REPORT" 2>/dev/null || echo unknown)"
    deny "$rule"
  fi
  # any other rc: gitleaks itself errored -> fall through to the regex net
fi

# ── fallback: minimal regex net when gitleaks is unavailable ───────────────
ALLOW='<[A-Za-z0-9_.-]*>|placeholder|example|changeme|your[_-]?(token|secret|password|key)|xxxx+|\*{4,}'
RULES=(
  'dpat-token|dpat_[a-f0-9]{64}'
  'github-token|(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82})'
  'sk-api-key|sk-[A-Za-z0-9_-]{20,}'
  'aws-access-key-id|AKIA[0-9A-Z]{16}'
  'private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'postgres-uri-password|postgres(ql)?://[A-Za-z0-9_.-]+:[^@/[:space:]]+@'
  'iteris-sync-token|ITERIS_SYNC_TOKEN[[:space:]]*[=:][[:space:]]*['"'"'"]?[A-Za-z0-9_-]{8,}'
)
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -n "$line" ]] || continue
  grep -qiE "$ALLOW" <<<"$line" && continue
  for rule in "${RULES[@]}"; do
    grep -qE -e "${rule#*|}" <<<"$line" && deny "${rule%%|*}"
  done
done < "$TMP_CONTENT"

exit 0
