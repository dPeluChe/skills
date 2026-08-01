# shellcheck shell=bash
# shellcheck disable=SC2154  # TMP/REPO_DIR/INSTALL/FLOWKIT come from 00-helpers.sh via the runner
# ── flowkit CLI: pure dispatch over install.sh + version surface ────────────

if [[ -x "$FLOWKIT" ]]; then
  ok "bin/flowkit present and executable"

  # help: exit 0, lists subcommands + the process repo
  if "$FLOWKIT" help > "$TMP/fk-help.log" 2>&1 \
     && grep -q "hooks" "$TMP/fk-help.log" \
     && grep -q "upgrade" "$TMP/fk-help.log" \
     && grep -q "github.com/dPeluChe/skills" "$TMP/fk-help.log"; then
    ok "flowkit help: exit 0, subcommands listed, process repo named"
  else
    nope "flowkit help: expected exit 0 with subcommand list (see $TMP/fk-help.log)"
  fi

  # unknown subcommand: help + exit 1, culprit named
  if "$FLOWKIT" frobnicate > "$TMP/fk-bad.log" 2>&1; then
    nope "flowkit: unknown subcommand should exit 1"
  elif grep -q "unknown subcommand: frobnicate" "$TMP/fk-bad.log" \
     && grep -q "Usage: flowkit" "$TMP/fk-bad.log"; then
    ok "flowkit: unknown subcommand prints help + exit 1, culprit named"
  else
    nope "flowkit: exit 1 but help/culprit missing (see $TMP/fk-bad.log)"
  fi

  # dispatch: `flowkit check` must be byte-identical to install.sh --check
  # (isolated chain dirs so the result is deterministic for both runs)
  FK_ENV=(AGENTS_SKILLS_DIR="$TMP/fk-agents" CLAUDE_SKILLS_DIR="$TMP/fk-claude" \
          FLOWKIT_BIN_DIR="$TMP/fk-bin-env")
  env "${FK_ENV[@]}" bash "$INSTALL" --check > "$TMP/fk-direct.log" 2>&1
  direct_rc=$?
  env "${FK_ENV[@]}" "$FLOWKIT" check > "$TMP/fk-dispatch.log" 2>&1
  dispatch_rc=$?
  if [[ "$dispatch_rc" -eq "$direct_rc" ]] && cmp -s "$TMP/fk-direct.log" "$TMP/fk-dispatch.log"; then
    ok "flowkit check: output and exit code ($dispatch_rc) identical to install.sh --check"
  else
    nope "flowkit check: dispatch diverges from install.sh --check (rc $dispatch_rc vs $direct_rc)"
  fi

  # about outside a git repo: static orientation only, exit 0
  mkdir -p "$TMP/fk-notrepo"
  if ( cd "$TMP/fk-notrepo" && "$FLOWKIT" about ) > "$TMP/fk-about-static.log" 2>&1 \
     && grep -q "github.com/dPeluChe/skills" "$TMP/fk-about-static.log" \
     && grep -q "harness guards" "$TMP/fk-about-static.log" \
     && grep -q "CI backstop" "$TMP/fk-about-static.log" \
     && ! grep -q "This repo (" "$TMP/fk-about-static.log"; then
    ok "flowkit about (outside a repo): static part only, exit 0"
  else
    nope "flowkit about (outside a repo): wrong output or non-zero exit (see $TMP/fk-about-static.log)"
  fi

  # about inside a repo fixture: static + coherent dynamic status
  FK_ABOUT="$TMP/fk-about-repo"
  make_repo "$FK_ABOUT"
  printf 'remotes: []\n' > "$FK_ABOUT/lefthook-local.yml"
  printf '[]\n' > "$FK_ABOUT/.gitleaks-baseline.json"
  cat > "$FK_ABOUT/CLAUDE.md" <<'EOF'
# Fixture

@~/.agents/skills/FLOW_CLAUDE.md

## ship config

```yaml
lint:            # TODO e.g. npm run lint
```
EOF
  if ( cd "$FK_ABOUT" && CLAUDE_SETTINGS_FILE="$TMP/fk-about-nosettings.json" "$FLOWKIT" about ) \
       > "$TMP/fk-about-dyn.log" 2>&1 \
     && grep -q "This repo (fk-about-repo)" "$TMP/fk-about-dyn.log" \
     && grep -q "hooks mode:      lefthook-local.yml (personal)" "$TMP/fk-about-dyn.log" \
     && grep -q "baseline:        present, 0 findings grandfathered" "$TMP/fk-about-dyn.log" \
     && grep -q "ship config:     present (TODOs pending)" "$TMP/fk-about-dyn.log" \
     && grep -q "FLOW import:     yes" "$TMP/fk-about-dyn.log" \
     && grep -q "harness guards:  not installed" "$TMP/fk-about-dyn.log" \
     && grep -q "Suggested next (read-only" "$TMP/fk-about-dyn.log" \
     && grep -q "fill the '## ship config' TODOs" "$TMP/fk-about-dyn.log" \
     && [[ -z "$(git -C "$FK_ABOUT" status --porcelain --untracked-files=no)" ]]; then
    ok "flowkit about (inside a repo): dynamic status + read-only 'Suggested next' advice, writes nothing"
  else
    nope "flowkit about (inside a repo): dynamic lines wrong (see $TMP/fk-about-dyn.log)"
  fi

  # symlink resolution: run through a symlink exactly like ~/bin/flowkit does
  mkdir -p "$TMP/fk-symdir"
  ln -s "$FLOWKIT" "$TMP/fk-symdir/flowkit"
  if "$TMP/fk-symdir/flowkit" help > "$TMP/fk-sym.log" 2>&1 \
     && grep -q "github.com/dPeluChe/skills" "$TMP/fk-sym.log"; then
    ok "flowkit via symlink: resolves its real repo, help works"
  else
    nope "flowkit via symlink: could not resolve repo through the link"
  fi
  env "${FK_ENV[@]}" "$TMP/fk-symdir/flowkit" check > "$TMP/fk-sym-check.log" 2>&1
  sym_rc=$?
  if [[ "$sym_rc" -eq "$direct_rc" ]] && cmp -s "$TMP/fk-sym-check.log" "$TMP/fk-direct.log"; then
    ok "flowkit via symlink: check dispatch identical to direct install.sh --check"
  else
    nope "flowkit via symlink: check diverges (rc $sym_rc vs $direct_rc)"
  fi

  # ── version: VERSION file + `flowkit version` + surfacing in help/about ───
  if [[ "$(cat "$REPO_DIR/VERSION" 2>/dev/null)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ok "VERSION file present at repo root with a semver value ($(cat "$REPO_DIR/VERSION"))"
  else
    nope "VERSION file missing or not semver (found: '$(cat "$REPO_DIR/VERSION" 2>/dev/null)')"
  fi

  EXPECT_VER="flowkit $(cat "$REPO_DIR/VERSION" 2>/dev/null) ($(git -C "$REPO_DIR" rev-parse --short HEAD))"
  if [[ "$("$FLOWKIT" version 2>&1)" == "$EXPECT_VER" ]]; then
    ok "flowkit version: prints '$EXPECT_VER' (VERSION file + repo short sha), exit 0"
  else
    nope "flowkit version: expected '$EXPECT_VER', got '$("$FLOWKIT" version 2>&1)'"
  fi

  if [[ "$("$FLOWKIT" --version 2>&1)" == "$EXPECT_VER" ]] \
     && [[ "$("$FLOWKIT" -v 2>&1)" == "$EXPECT_VER" ]]; then
    ok "flowkit --version / -v: aliases match the version line"
  else
    nope "flowkit --version / -v: aliases diverge from '$EXPECT_VER'"
  fi

  if [[ "$(head -1 "$TMP/fk-help.log")" == "$EXPECT_VER"* ]]; then
    ok "flowkit help: version on the first line"
  else
    nope "flowkit help: first line lacks the version (got: $(head -1 "$TMP/fk-help.log"))"
  fi

  if [[ "$(head -1 "$TMP/fk-about-static.log")" == "$EXPECT_VER"* ]]; then
    ok "flowkit about: version on the first line"
  else
    nope "flowkit about: first line lacks the version (got: $(head -1 "$TMP/fk-about-static.log"))"
  fi

  if grep -qF "$EXPECT_VER" "$TMP/fk-direct.log"; then
    ok "install.sh --check: reports the flowkit version"
  else
    nope "install.sh --check: version line missing (see $TMP/fk-direct.log)"
  fi
else
  nope "bin/flowkit missing or not executable"
fi
