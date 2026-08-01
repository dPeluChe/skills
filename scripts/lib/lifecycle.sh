# shellcheck shell=bash
# shellcheck disable=SC2154  # globals (TARGET_REPO, CLAUDE_SETTINGS, ...) come from install.sh
# ── lifecycle: unhook, about, harness guards, upgrade ──────────────────────
# Sourced by scripts/install.sh (the entrypoint); never executed directly.

# ── unhook (--unhook <path>): clean removal of OUR wiring from one repo ─────
run_unhook() {
  local target gitdir ehp d f rel base line
  local removed=()
  target="$(cd "$TARGET_REPO" 2>/dev/null && pwd)" || die "not a directory: $TARGET_REPO"
  git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $target"
  gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
  ehp="$(effective_hooks_dir "$target")"

  # lefthook stubs: effective hooksPath + .git/hooks. Tracked files that
  # mention lefthook (a project-owned delegation) are respected with a notice.
  local dirs=("$gitdir/hooks")
  if [[ "$ehp" != "$gitdir/hooks" ]]; then
    case "$ehp" in
      "$target"/*|"$gitdir"/*) dirs+=("$ehp") ;;
      *) note "! effective hooksPath ($ehp) lives outside this repo (shared by others) -- not touched" ;;
    esac
  fi
  for d in "${dirs[@]}"; do
    for f in "$d"/*; do
      [[ -f "$f" ]] || continue
      grep -q lefthook "$f" 2>/dev/null || continue
      case "$f" in
        "$gitdir"/*) ;;
        "$target"/*)
          rel="${f#"$target"/}"
          if git -C "$target" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
            note "! $rel is TRACKED and mentions lefthook -- left in place (remove the delegation line via PR if unwanted)"
            continue
          fi
          ;;
      esac
      rm -f "$f"
      removed+=("lefthook stub|$f")
    done
  done

  # OUR config files: only the ones referencing our remote AND untracked.
  for base in lefthook.yml lefthook-local.yml; do
    f="$target/$base"
    [[ -f "$f" ]] || continue
    if git -C "$target" ls-files --error-unmatch "$base" >/dev/null 2>&1; then
      note "! $base is tracked (project-owned) -- left in place"
    elif grep -qF "$REMOTE_URL" "$f"; then
      rm -f "$f"
      removed+=("our config|$f")
    else
      note "! $base does not reference $REMOTE_URL (not ours) -- left in place"
    fi
  done

  # OUR .git/info/exclude entries (written by --team wiring).
  for line in "CLAUDE.local.md" ".gitleaks-baseline.json"; do
    if exclude_remove "$target" "$line"; then
      removed+=("exclude entry|$line (.git/info/exclude)")
    fi
  done

  echo ""
  echo "-- unhook report ($target)"
  if [[ "${#removed[@]}" -eq 0 ]]; then
    echo "  nothing to remove -- repo was not wired (or already clean)"
  else
    printf '  %-16s %s\n' "removed" "what"
    printf '  %-16s %s\n' "-------" "----"
    for f in "${removed[@]}"; do
      printf '  %-16s %s\n' "${f%%|*}" "${f##*|}"
    done
  fi
  exit 0
}

# -- about (--about): orientation for agents landing cold on a repo -----------
run_about() {
  echo "$(flowkit_version) -- manager for the skills + hooks + flow layer (github.com/dPeluChe/skills)"
  cat <<'EOF'

Four layers keep agent-driven work consistent and safe:
  1. harness guards    Claude Code PreToolUse hooks (git-guard, secret-guard)
  2. git hooks         centralized lefthook config fetched from this repo
  3. ship skill gates  lint/build/test read from '## ship config' in CLAUDE.md
  4. CI backstop       the same checks re-run server-side

Each repo's commands live in the '## ship config' block of its CLAUDE.md.
EOF
  git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0

  local root name hooks_mode="none" baseline="none" ship="absent" flow="no"
  local guards="not installed" n ehp gitdir f orphan=0
  root="$(git rev-parse --show-toplevel)"
  name="$(basename "$root")"
  if git -C "$root" ls-files --error-unmatch lefthook.yml >/dev/null 2>&1; then
    hooks_mode="lefthook.yml (committed)"
  elif [[ -f "$root/lefthook-local.yml" ]]; then
    hooks_mode="lefthook-local.yml (personal)"
  elif [[ -f "$root/lefthook.yml" ]]; then
    hooks_mode="lefthook.yml (untracked)"
  fi
  if [[ -f "$root/.gitleaks-baseline.json" ]]; then
    n="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' \
      "$root/.gitleaks-baseline.json" 2>/dev/null || echo "?")"
    baseline="present, $n findings grandfathered"
  fi
  if grep -q '^## ship config' "$root/CLAUDE.md" 2>/dev/null; then
    if ship_config_has_todos "$root/CLAUDE.md"; then
      ship="present (TODOs pending)"
    else
      ship="present"
    fi
  fi
  grep -qF '@~/.agents/skills/FLOW_CLAUDE.md' "$root/CLAUDE.md" 2>/dev/null && flow="yes"
  if grep -qF 'hooks-harness/git-guard.sh' "$CLAUDE_SETTINGS" 2>/dev/null \
     && grep -qF 'hooks-harness/secret-guard.sh' "$CLAUDE_SETTINGS" 2>/dev/null; then
    guards="installed"
  fi
  # orphan stubs: lefthook hook files present with no config at all --
  # every push errors out; unhook is the way out (same advice as --verify)
  if [[ ! -f "$root/lefthook.yml" && ! -f "$root/lefthook-local.yml" ]]; then
    ehp="$(effective_hooks_dir "$root")"
    gitdir="$(git -C "$root" rev-parse --absolute-git-dir)"
    for f in "$ehp"/* "$gitdir"/hooks/*; do
      [[ -f "$f" ]] && grep -q lefthook "$f" 2>/dev/null && { orphan=1; break; }
    done
  fi
  echo ""
  echo "This repo ($name):"
  echo "  hooks mode:      $hooks_mode"
  echo "  baseline:        $baseline"
  echo "  ship config:     $ship"
  echo "  FLOW import:     $flow"
  echo "  harness guards:  $guards"
  if [[ "$orphan" == 1 ]]; then
    echo "  orphan stubs:    lefthook stubs with NO config -- pushes will fail; run: flowkit unhook"
  fi
  exit 0
}

# ── Claude Code harness hooks (--harness): PreToolUse guards ───────────────
# git-guard.sh (matcher Bash) + secret-guard.sh (matcher Edit|Write) served
# through ~/.agents/hooks-harness and registered in ~/.claude/settings.json.

ensure_harness_link() {
  local src="$REPO_DIR/hooks/harness" link="$HARNESS_LINK"
  [[ -d "$src" ]] || { bad "hooks/harness missing from repo"; return 0; }
  if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
    [[ "$MODE" == "check" ]] || note "-> harness link ok  $link"
  elif [[ -e "$link" && ! -L "$link" ]]; then
    bad "$link exists and is not a symlink -- remove it to adopt"
  else
    [[ "$MODE" == "check" ]] && { bad "harness link missing/wrong ($link)"; return 0; }
    mkdir -p "$(dirname "$link")"
    rm -f "$link"; ln -s "$src" "$link"; note "-> harness linked  $link"
  fi
}

merge_harness_settings() { # merge (or, in check mode, audit) the 2 guard entries
  # in $CLAUDE_SETTINGS. Prints ADDED/PRESENT/MISSING lines; everything else in
  # the JSON is preserved verbatim. Backup to settings.json.bak before writing.
  python3 - "$CLAUDE_SETTINGS" "$MODE" <<'PY'
import json, os, shutil, sys

path, mode = sys.argv[1], sys.argv[2]
wanted = [
    ("Bash", "$HOME/.agents/hooks-harness/git-guard.sh"),
    ("Edit|Write", "$HOME/.agents/hooks-harness/secret-guard.sh"),
]

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except ValueError:
        print(f"MALFORMED {path}")
        sys.exit(3)

pre = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
added, present = [], []
for matcher, cmd in wanted:
    entry = next((e for e in pre if e.get("matcher") == matcher), None)
    if entry is not None and any(
        h.get("command") == cmd for h in entry.get("hooks", [])
    ):
        present.append(f"{matcher} -> {cmd}")
        continue
    if mode != "check":
        if entry is None:
            pre.append({"matcher": matcher,
                        "hooks": [{"type": "command", "command": cmd}]})
        else:
            entry.setdefault("hooks", []).append(
                {"type": "command", "command": cmd})
    added.append(f"{matcher} -> {cmd}")

if mode != "check" and added:
    if os.path.exists(path):
        shutil.copyfile(path, path + ".bak")
    else:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

for line in present:
    print("PRESENT " + line)
for line in added:
    print(("MISSING " if mode == "check" else "ADDED ") + line)
PY
}

install_harness() {
  ensure_harness_link
  local out rc=0
  out="$(merge_harness_settings)" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    bad "settings merge failed: ${out:-python3 error} -- fix $CLAUDE_SETTINGS and re-run"
  else
    local line
    while IFS= read -r line; do
      case "$line" in
        ADDED\ *)   note "-> settings: added        ${line#ADDED }" ;;
        PRESENT\ *) note "-> settings: already there ${line#PRESENT }" ;;
      esac
    done <<<"$out"
  fi
  if [[ "$PROBLEMS" -gt 0 ]]; then
    problem_summary
    exit 1
  fi
  echo "-- harness hooks wired ($CLAUDE_SETTINGS). New Claude Code sessions pick them up."
  exit 0
}

check_harness() { # --check: validate link + settings entries once installed;
  # a machine that never ran --harness stays green (opt-in feature).
  local src="$REPO_DIR/hooks/harness" link="$HARNESS_LINK" out line rc=0
  out="$(merge_harness_settings)" || rc=$?
  [[ "$rc" -eq 0 ]] || { bad "harness: could not read $CLAUDE_SETTINGS (${out:-python3 error})"; return 0; }
  local link_ok=0
  [[ -L "$link" && "$(readlink "$link")" == "$src" ]] && link_ok=1
  if [[ "$link_ok" -eq 0 && ! -e "$link" ]] && ! grep -q '^PRESENT' <<<"$out"; then
    note "- harness hooks not installed (optional -- run: make harness)"
    return 0
  fi
  [[ "$link_ok" -eq 1 ]] || bad "harness link missing/wrong ($link)"
  if grep -q '^MISSING' <<<"$out"; then
    while IFS= read -r line; do
      [[ "$line" == MISSING\ * ]] && bad "harness settings entry missing: ${line#MISSING }"
    done <<<"$out"
  elif [[ "$link_ok" -eq 1 ]]; then
    note "ok harness hooks (link + 2 settings entries)"
  fi
}

# ── upgrade: versions vs minimums + this clone vs origin/main (--upgrade) ──
UPGRADE_PENDING=0

report_tool_upgrade() { # $1 = tool, $2 = required minimum; $BREW_OUTDATED may list it
  local name="$1" min="$2" cur
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "x $name: not installed - min $min -- brew install $name"
    UPGRADE_PENDING=1
    return 0
  fi
  cur="$(tool_version "$name")"
  if ! ver_ge "${cur:-0}" "$min"; then
    echo "x $name: ${cur:-?} - min $min - BELOW minimum -- brew upgrade $name"
    UPGRADE_PENDING=1
  elif [[ -n "$BREW_OUTDATED" ]] && grep -qxF "$name" <<<"$BREW_OUTDATED"; then
    echo "! $name: $cur - min $min ok - newer in brew -- brew upgrade $name"
    UPGRADE_PENDING=1
  else
    echo "ok $name: $cur - min $min - up to date"
  fi
}

run_upgrade() {
  BREW_OUTDATED=""
  if command -v brew >/dev/null 2>&1; then
    BREW_OUTDATED="$(brew outdated --quiet 2>/dev/null || true)"
  fi
  report_tool_upgrade lefthook "$MIN_LEFTHOOK"
  report_tool_upgrade gitleaks "$MIN_GITLEAKS"

  # standing inside a WIRED repo: refresh that repo's lefthook remotes cache so
  # a just-merged hooks change lands now instead of after the 24h refetch window
  local cwd_root="" cwd_gitdir
  cwd_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$cwd_root" && "$cwd_root" != "$REPO_DIR" ]] \
     && command -v lefthook >/dev/null 2>&1 \
     && lefthook_cfg_file "$cwd_root" >/dev/null; then
    cwd_gitdir="$(git -C "$cwd_root" rev-parse --absolute-git-dir)"
    if ( cd "$cwd_root" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
        GIT_CONFIG_VALUE_0="$cwd_gitdir/hooks" lefthook install --force >/dev/null 2>&1 ); then
      echo "ok $(basename "$cwd_root"): remotes refreshed (lefthook install re-synced this repo's cache)"
    else
      echo "x $(basename "$cwd_root"): lefthook install failed -- remotes NOT refreshed"
      UPGRADE_PENDING=1
    fi
  fi

  # this skills clone vs its public remote — report only, never pull
  local behind
  if git -C "$REPO_DIR" fetch --quiet origin 2>/dev/null; then
    behind="$(git -C "$REPO_DIR" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")"
    if [[ "$behind" == "0" ]]; then
      echo "ok skills repo: up to date with origin/main"
    else
      echo "! skills repo: $behind commit(s) behind origin/main -- run: git pull && make install"
      UPGRADE_PENDING=1
    fi
  else
    echo "x skills repo: could not fetch origin -- check network/remote"
    UPGRADE_PENDING=1
  fi

  if [[ "$UPGRADE_PENDING" -gt 0 ]]; then
    echo "-- updates pending"
    exit 1
  fi
  echo "-- everything up to date"
  exit 0
}
