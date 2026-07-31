# shellcheck shell=bash
# shellcheck disable=SC2034  # BASE_YML/INSTALL/FLOWKIT are consumed by sibling modules
# Shared state + assert helpers for the modules in this directory.
# Sourced FIRST by scripts/test-hooks.sh (which sets $REPO_DIR); every module
# then runs in the same shell and shares $TMP, the counters and these helpers.

BASE_YML="$REPO_DIR/hooks/lefthook-base.yml"
INSTALL="$REPO_DIR/scripts/install.sh"
FLOWKIT="$REPO_DIR/bin/flowkit"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Point lefthook `remotes` at a MINIMAL local repo, not github. The canary and
# verify tests run the effective hook, which fetches the remote config; hitting
# github made the suite flaky (~1/6) and, under heavy testing, rate-limited to
# consistent failure. This local git_url clones offline and deterministic. It
# carries only the two hook configs, committed on main -- no full-repo clone
# side effects. Fixtures reference $REMOTE_URL (never a hardcoded github URL) so
# lefthook_cfg_file matches.
FF_REMOTE="$TMP/ff-remote"
mkdir -p "$FF_REMOTE/hooks"
cp "$REPO_DIR/hooks/lefthook-base.yml" "$FF_REMOTE/hooks/"
cp "$REPO_DIR/hooks/.gitleaks.toml" "$FF_REMOTE/hooks/"
git -C "$FF_REMOTE" init -q -b main 2>/dev/null || git -C "$FF_REMOTE" init -q
git -C "$FF_REMOTE" add -A
git -C "$FF_REMOTE" -c user.email=t@t.t -c user.name=t commit -q -m hooks
export REMOTE_URL="$FF_REMOTE"

# Minimal LOCAL remote for lefthook: a tiny git repo carrying only the two hook
# configs, committed on main. The canary runs the effective hook which fetches
# `remotes` -- pointing at github made the suite flaky (~1/6 network blips).
# A local git_url clones offline and deterministic, without the full-repo
# clone side-effects that broke the upgrade/0-jobs tests.
FF_REMOTE="$TMP/ff-remote"
mkdir -p "$FF_REMOTE/hooks"
cp "$REPO_DIR/hooks/lefthook-base.yml" "$FF_REMOTE/hooks/"
cp "$REPO_DIR/hooks/.gitleaks.toml" "$FF_REMOTE/hooks/"
git -C "$FF_REMOTE" init -q -b main
git -C "$FF_REMOTE" add -A
git -C "$FF_REMOTE" -c user.email=t@t.t -c user.name=t commit -q -m "hooks"
export REMOTE_URL="$FF_REMOTE"

PASS=0; FAIL=0
ok()   { echo "✓ $*"; PASS=$((PASS + 1)); }
nope() { echo "✗ $*"; FAIL=$((FAIL + 1)); }

make_repo() { # $1 = dir — git repo with one commit
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m init
}
