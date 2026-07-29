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

PASS=0; FAIL=0
ok()   { echo "✓ $*"; PASS=$((PASS + 1)); }
nope() { echo "✗ $*"; FAIL=$((FAIL + 1)); }

make_repo() { # $1 = dir — git repo with one commit
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" -c user.email=t@t.t -c user.name=t commit -q --allow-empty -m init
}
