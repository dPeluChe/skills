# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/INSTALL come from 00-helpers.sh via the runner
# ── re-running flowkit hooks must not destroy the repo's own work: baseline
#    classifications, jobs migrated into lefthook.yml ─────────────────────────

if command -v lefthook >/dev/null 2>&1 && command -v gitleaks >/dev/null 2>&1 \
   && command -v python3 >/dev/null 2>&1; then
  RW_GCFG="$TMP/rw-gitconfig"; : > "$RW_GCFG"
  run_rw() {
    AGENTS_SKILLS_DIR="$TMP/rw-agents" CLAUDE_SKILLS_DIR="$TMP/rw-claude" \
      GIT_CONFIG_GLOBAL="$RW_GCFG" bash "$INSTALL" "$@" \
      > "$TMP/out.log" 2> "$TMP/err.log" < /dev/null
  }

  RW="$TMP/rw-repo"
  make_repo "$RW"
  # split literal: this repo's own pre-commit scan must not see a full key
  printf 'aws_key = "%s%s"\n' "AKIA" "Z7Q4RT2XW9LMN3BV" > "$RW/legacy.cfg"
  git -C "$RW" add legacy.cfg && git -C "$RW" -c user.email=t@t.t -c user.name=t commit -qm "legacy key" --no-gpg-sign

  if run_rw --repo "$RW" && [[ -s "$RW/.gitleaks-baseline.json" ]]; then
    python3 - "$RW/.gitleaks-baseline.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for x in d:
    x["classification"] = "real-rotate"
    x["note"] = "rotated 2026-11"
json.dump(d, open(p, "w"), indent=2)
PY
    printf '\npre-commit:\n  jobs:\n    - name: repo-own-check\n      run: "true"\n' >> "$RW/lefthook.yml"

    if run_rw --repo "$RW"; then
      if python3 - "$RW/.gitleaks-baseline.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ok = d and all(x.get("classification") == "real-rotate" and x.get("note") == "rotated 2026-11" for x in d)
sys.exit(0 if ok else 1)
PY
      then
        ok "re-wire: baseline classification + note survive a second flowkit hooks"
      else
        nope "re-wire: baseline classifications were reset (see $RW/.gitleaks-baseline.json)"
      fi
      if grep -q 'repo-own-check' "$RW/lefthook.yml"; then
        ok "re-wire: an already-wired lefthook.yml keeps the repo's own jobs"
      else
        nope "re-wire: lefthook.yml was rewritten, the repo's own job is gone"
      fi
    else
      nope "re-wire: second flowkit hooks run exited non-zero (see $TMP/out.log)"
    fi
  else
    nope "re-wire: first wiring produced no baseline (see $TMP/out.log)"
  fi
fi
