# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL/FLOWKIT come from 00-helpers.sh via the runner
# ── lint-health: alert on false-green lint gates in JS/TS/React repos ──
# Doctrine mirror of gitleaks:allow: a scoped REASONED eslint-disable is fine; a
# BLANKET or config-wide OFF rule is a false green. The check ALERTS (exit 0),
# never auto-fixes, never blocks. Field cases baked in: tennispro (no-explicit-any
# off in flat config) + ligamx (blanket /* eslint-disable */ vs one good scoped one).
# All code-with-disable fixtures are assembled AT RUNTIME (source stays clean).

# README: the doctrine + the --measure use must be documented
if grep -q "Lint health" "$REPO_DIR/README.md" \
   && grep -q "false green" "$REPO_DIR/README.md" \
   && grep -q "lint-health --measure" "$REPO_DIR/README.md"; then
  ok "README: lint-health doctrine (scoped-vs-blanket) + --measure documented"
else
  nope "README: lint-health section missing (doctrine or --measure)"
fi

# ship SKILL.md: quality pass runs lint-health on the DIFF
if grep -q "Lint health on the diff" "$REPO_DIR/skills/ship/SKILL.md" \
   && grep -q "flowkit lint-health" "$REPO_DIR/skills/ship/SKILL.md"; then
  ok "ship SKILL.md: Step 2 runs lint-health on the diff (new blanket/off = finding)"
else
  nope "ship SKILL.md: lint-health-on-diff step missing"
fi

# flowkit help lists the subcommand
if "$FLOWKIT" help 2>&1 | grep -q "lint-health"; then
  ok "flowkit help: lint-health subcommand listed"
else
  nope "flowkit help: lint-health not listed"
fi

# ── (1) blanket /* eslint-disable */ -> flagged, ALERT, exit 0 (ligamx case) ─
LH_BLANK="$TMP/lh-blanket"
mkdir -p "$LH_BLANK/src"
printf 'export default []\n' > "$LH_BLANK/eslint.config.js"
cat > "$LH_BLANK/src/legacy.ts" <<'EOF'
/* eslint-disable */
export const x: any = 1
EOF
# a GOOD scoped reasoned disable in the same repo must NOT inflate the count
cat > "$LH_BLANK/src/typed.ts" <<'EOF'
/* eslint-disable @typescript-eslint/no-explicit-any -- upstream types are wrong */
export const y: any = 2
EOF
if "$FLOWKIT" lint-health "$LH_BLANK" > "$TMP/lh-blank.log" 2>&1; then
  if grep -q "1 blanket disable" "$TMP/lh-blank.log" \
     && grep -q "src/legacy.ts:1" "$TMP/lh-blank.log" \
     && grep -q "^ALERT:" "$TMP/lh-blank.log" \
     && ! grep -q "src/typed.ts" "$TMP/lh-blank.log"; then
    ok "blanket: /* eslint-disable */ flagged with file:line, scoped one ignored, ALERT + exit 0"
  else
    nope "blanket: expected 1 blanket + ALERT, scoped ignored (see $TMP/lh-blank.log)"
  fi
else
  nope "blanket: lint-health must exit 0 (advisory, never blocks)"
fi

# ── (2) ONLY a reasoned scoped disable -> clean, no ALERT ────────────────────
LH_CLEAN="$TMP/lh-clean"
mkdir -p "$LH_CLEAN/src"
printf 'export default []\n' > "$LH_CLEAN/eslint.config.js"
cat > "$LH_CLEAN/src/ok.ts" <<'EOF'
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- json blob from a vendor
export const z: any = 3
EOF
if "$FLOWKIT" lint-health "$LH_CLEAN" > "$TMP/lh-clean.log" 2>&1 \
   && grep -q "no blanket disables" "$TMP/lh-clean.log" \
   && grep -q "lint gate looks honest" "$TMP/lh-clean.log" \
   && ! grep -q "ALERT" "$TMP/lh-clean.log"; then
  ok "scoped-reasoned: repo with only a reasoned scoped disable is clean (no ALERT)"
else
  nope "scoped-reasoned: reasoned scoped disable should NOT be flagged (see $TMP/lh-clean.log)"
fi

# ── (3) config with no-explicit-any off -> rule reported (tennispro case) ────
LH_CFG="$TMP/lh-cfg-off"
mkdir -p "$LH_CFG"
cat > "$LH_CFG/eslint.config.js" <<'EOF'
export default [
  { rules: {
      "@typescript-eslint/no-explicit-any": "off",
      "no-console": 0,
  } },
]
EOF
if "$FLOWKIT" lint-health "$LH_CFG" > "$TMP/lh-cfg.log" 2>&1 \
   && grep -q "OFF in the config TEXT" "$TMP/lh-cfg.log" \
   && grep -q "eslint --print-config" "$TMP/lh-cfg.log" \
   && grep -q "@typescript-eslint/no-explicit-any (in eslint.config.js)" "$TMP/lh-cfg.log" \
   && grep -q "no-console (in eslint.config.js)" "$TMP/lh-cfg.log" \
   && grep -q "^ALERT:" "$TMP/lh-cfg.log"; then
  ok "config-off (no eslint): off-rules named as TEXT candidates + print-config caveat, ALERT"
else
  nope "config-off: off-rules not named or missing the text-read caveat (see $TMP/lh-cfg.log)"
fi

# ── (3b) authoritative scope: a rule that the config text shows "off" but is
# actually ON for source (a scoped `files:` override) must NOT be reported as
# repo-wide off. Field bug (tennispro): text read can't see flat-config scope;
# `eslint --print-config` can. Stub eslint reports the candidate as severity 2.
LH_SCOPED="$TMP/lh-scoped"
mkdir -p "$LH_SCOPED/src" "$LH_SCOPED/node_modules/.bin"
cat > "$LH_SCOPED/eslint.config.js" <<'EOF'
export default [
  { rules: { "no-console": "off" } },
  { files: ["migrations/**"], rules: { "@typescript-eslint/no-explicit-any": "off" } },
]
EOF
printf 'export const a = 1\n' > "$LH_SCOPED/src/a.ts"
cat > "$LH_SCOPED/node_modules/.bin/eslint" <<'STUB'
#!/bin/sh
# --print-config: no-explicit-any is ON (2) for source, no-console genuinely off (0)
case "$*" in
  *--print-config*) printf '%s\n' '{"rules":{"@typescript-eslint/no-explicit-any":[2],"no-console":[0]}}' ;;
esac
STUB
chmod +x "$LH_SCOPED/node_modules/.bin/eslint"
if "$FLOWKIT" lint-health "$LH_SCOPED" > "$TMP/lh-scoped.log" 2>&1 \
   && grep -q "1 rule(s) OFF repo-wide (verified via eslint --print-config)" "$TMP/lh-scoped.log" \
   && grep -q "no-console (in eslint.config.js)" "$TMP/lh-scoped.log" \
   && grep -q "scoped override(s).*@typescript-eslint/no-explicit-any" "$TMP/lh-scoped.log" \
   && ! grep -q "no-explicit-any (in eslint.config.js)" "$TMP/lh-scoped.log"; then
  ok "scope: print-config keeps genuinely-off (no-console), demotes scoped override (no-explicit-any)"
else
  nope "scope: authoritative print-config filter did not separate repo-wide from scoped (see $TMP/lh-scoped.log)"
fi

# ── (4) no eslint config -> N/A, exit 0 ──────────────────────────────────────
LH_NONE="$TMP/lh-none"
mkdir -p "$LH_NONE/src"
printf 'const q = 1\n' > "$LH_NONE/src/x.ts"
if "$FLOWKIT" lint-health "$LH_NONE" > "$TMP/lh-none.log" 2>&1 \
   && grep -q "no eslint config -- lint-health N/A" "$TMP/lh-none.log"; then
  ok "guard: no eslint config -> 'lint-health N/A', exit 0"
else
  nope "guard: repo without eslint config should be N/A exit 0 (see $TMP/lh-none.log)"
fi

# ── (4b) a package.json "lint" script alone satisfies the guard (runs) ──────
LH_SCRIPT="$TMP/lh-lintscript"
mkdir -p "$LH_SCRIPT/src"
printf '{ "scripts": { "lint": "eslint ." } }\n' > "$LH_SCRIPT/package.json"
cat > "$LH_SCRIPT/src/a.ts" <<'EOF'
/* eslint-disable */
export const w = 1
EOF
if "$FLOWKIT" lint-health "$LH_SCRIPT" > "$TMP/lh-script.log" 2>&1 \
   && ! grep -q "N/A" "$TMP/lh-script.log" \
   && grep -q "1 blanket disable" "$TMP/lh-script.log"; then
  ok "guard: a package.json lint script alone makes lint-health run (not N/A)"
else
  nope "guard: lint script should satisfy the guard and run (see $TMP/lh-script.log)"
fi

# ── (5) ignored source path -> flagged; usual build output -> not ───────────
LH_IGN="$TMP/lh-ignore"
mkdir -p "$LH_IGN"
printf 'export default []\n' > "$LH_IGN/eslint.config.js"
printf 'dist\nnode_modules\nsrc/legacy/\n' > "$LH_IGN/.eslintignore"
if "$FLOWKIT" lint-health "$LH_IGN" > "$TMP/lh-ign.log" 2>&1 \
   && grep -q "may cover SOURCE" "$TMP/lh-ign.log" \
   && grep -q "src/legacy/" "$TMP/lh-ign.log" \
   && ! grep -qE "\.eslintignore: (dist|node_modules)" "$TMP/lh-ign.log"; then
  ok "ignored-source: .eslintignore src/legacy flagged, dist/node_modules not"
else
  nope "ignored-source: non-standard ignore entry not isolated (see $TMP/lh-ign.log)"
fi

# ── (6) --measure without node_modules -> not runnable, exit 0 ──────────────
if "$FLOWKIT" lint-health --measure 'no-unused-vars' "$LH_BLANK" > "$TMP/lh-meas.log" 2>&1 \
   && grep -q "eslint not runnable" "$TMP/lh-meas.log" \
   && grep -q "measure skipped" "$TMP/lh-meas.log"; then
  ok "measure: no node_modules -> 'eslint not runnable', exit 0 (never blocks)"
else
  nope "measure: missing eslint should report not-runnable + exit 0 (see $TMP/lh-meas.log)"
fi

# ── (6b) STUB eslint present -> --measure counts + labels honestly, and the
# pipefail-safe JSON check survives. Regression guard: the old `printf|head -c1
# |grep` report-detection returned non-zero under `set -o pipefail` (head closes
# the pipe -> printf SIGPIPE) and mislabeled a REAL report as inconclusive. Stub
# prints fixed JSON + exit 1 (like eslint-with-findings); flat config => extended.
LH_MEAS="$TMP/lh-measure"
mkdir -p "$LH_MEAS/src" "$LH_MEAS/node_modules/.bin"
printf 'export default []\n' > "$LH_MEAS/eslint.config.js"
printf 'export const a = 1\n' > "$LH_MEAS/src/a.ts"
cat > "$LH_MEAS/node_modules/.bin/eslint" <<'STUB'
#!/bin/sh
cat <<'JSON'
[{"filePath":"a.ts","messages":[{"ruleId":"no-console"},{"ruleId":"no-console"}]},{"filePath":"b.ts","messages":[{"ruleId":"no-console"}]}]
JSON
exit 1
STUB
chmod +x "$LH_MEAS/node_modules/.bin/eslint"
if "$FLOWKIT" lint-health --measure 'no-console' "$LH_MEAS" > "$TMP/lh-meas2.log" 2>&1 \
   && grep -q "no-console forced on: 3 findings across 2 files" "$TMP/lh-meas2.log" \
   && grep -q "via extended config" "$TMP/lh-meas2.log"; then
  ok "measure: stub eslint -> 3 findings/2 files + extended-config label, pipefail-safe JSON check"
else
  nope "measure: stub count/label wrong or the pipefail-safe report check regressed (see $TMP/lh-meas2.log)"
fi

# ── (7) dispatch parity: flowkit lint-health == install.sh --lint-health ─────
"$FLOWKIT" lint-health "$LH_CFG" > "$TMP/lh-fk.log" 2>&1; fk_rc=$?
bash "$INSTALL" --lint-health "$LH_CFG" > "$TMP/lh-direct.log" 2>&1; dir_rc=$?
if [[ "$fk_rc" -eq "$dir_rc" ]] && cmp -s "$TMP/lh-fk.log" "$TMP/lh-direct.log"; then
  ok "dispatch: flowkit lint-health byte-identical to install.sh --lint-health (rc $fk_rc)"
else
  nope "dispatch: flowkit lint-health diverges from install.sh --lint-health (rc $fk_rc vs $dir_rc)"
fi

# ── (8) --canary: run the repo's OWN lint, plant a violation per extension, and
# classify caught / BLIND / parse-error. Field bug (blueprint-landings): .astro
# silently unlinted while lint stayed green. Stub eslint: --print-config says
# no-debugger is ON (so BLIND is never a false accusation); the lint run catches
# the .ts probe, is SILENT on .astro (blind), and parse-errors on .vue.
LH_CAN="$TMP/lh-canary"
mkdir -p "$LH_CAN/src" "$LH_CAN/node_modules/.bin"
printf '{ "scripts": { "lint": "eslint ." } }\n' > "$LH_CAN/package.json"
printf 'export const a = 1\n' > "$LH_CAN/src/a.ts"
printf -- '---\nexport const b = 2\n---\n<div></div>\n' > "$LH_CAN/src/a.astro"
printf '<script>export const c = 3</script>\n' > "$LH_CAN/src/a.vue"
cat > "$LH_CAN/node_modules/.bin/eslint" <<'STUB'
#!/bin/sh
case "$*" in
  *--print-config*) printf '%s\n' '{"rules":{"no-debugger":[2]}}' ;;
  *)
    printf '%s\n' 'src/__flowkit_canary__.ts'
    printf '  1:1  error  Unexpected debugger  no-debugger\n'
    printf '%s\n' 'src/__flowkit_canary__.vue'
    printf '  1:1  error  Parsing error: unexpected token\n'
    exit 1 ;;
esac
STUB
chmod +x "$LH_CAN/node_modules/.bin/eslint"
if "$FLOWKIT" lint-health --canary "$LH_CAN" > "$TMP/lh-can.log" 2>&1 \
   && grep -q "ok ts: a planted violation was caught" "$TMP/lh-can.log" \
   && grep -q "! astro: BLIND" "$TMP/lh-can.log" \
   && grep -q "! vue: PARSE ERROR" "$TMP/lh-can.log" \
   && grep -q "^ALERT:" "$TMP/lh-can.log" \
   && [[ -z "$(find "$LH_CAN" -name '__flowkit_canary__*' 2>/dev/null)" ]]; then
  ok "canary: ts caught, astro BLIND, vue PARSE ERROR, ALERT, probes cleaned up"
else
  nope "canary: classification wrong or probes left behind (see $TMP/lh-can.log)"
fi

# ── (8b) no lint script -> N/A (the canary probes the repo's own gate) ────────
LH_CANNA="$TMP/lh-canary-na"
mkdir -p "$LH_CANNA/src"
printf 'export default []\n' > "$LH_CANNA/eslint.config.js"
printf 'const x = 1\n' > "$LH_CANNA/src/a.ts"
if "$FLOWKIT" lint-health --canary "$LH_CANNA" > "$TMP/lh-canna.log" 2>&1 \
   && grep -q "no \"lint\" script" "$TMP/lh-canna.log" \
   && grep -q "N/A" "$TMP/lh-canna.log"; then
  ok "canary: no lint script -> N/A (nothing to probe), exit 0"
else
  nope "canary: missing lint script should be N/A (see $TMP/lh-canna.log)"
fi
