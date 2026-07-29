# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034,SC2153  # globals (TEAM, AGENT_ACTIONS, ...) live in install.sh/util.sh
# ── repo-wire: --repo mode -- wire centralized git hooks into target repos ──
# Sourced by scripts/install.sh (the entrypoint); never executed directly.

check_tool_versions() {
  local v missing=0
  if command -v lefthook >/dev/null 2>&1; then
    v="$(tool_version lefthook)"
    ver_ge "${v:-0}" "$MIN_LEFTHOOK" || { echo "x lefthook >= $MIN_LEFTHOOK required (found ${v:-?})"; missing=1; }
  else
    echo "x lefthook not found -- install it: brew install lefthook"; missing=1
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    v="$(tool_version gitleaks)"
    ver_ge "${v:-0}" "$MIN_GITLEAKS" || { echo "x gitleaks >= $MIN_GITLEAKS required for 'gitleaks git' (found ${v:-?})"; missing=1; }
  else
    echo "x gitleaks not found -- install it: brew install gitleaks"; missing=1
  fi
  [[ "$missing" == 0 ]] || die "missing/outdated tools -- install them and re-run"
}

write_remotes_config() { # $1 = destination yml path
  cat > "$1" <<EOF
# Managed by dPeluChe/skills scripts/install.sh --repo.
# Central hooks live in that repo (hooks/lefthook-base.yml); lefthook
# refetches them at most once a day.
remotes:
  - git_url: $REMOTE_URL
    ref: main
    refetch_frequency: 24h
    configs:
      - hooks/lefthook-base.yml
EOF
  note "-> wrote $(basename "$1")"
}

ensure_global_gitignore() { # team mode: lefthook-local.yml must be globally ignored
  local gi
  gi="$(git config --global core.excludesFile 2>/dev/null || true)"
  gi="${gi/#\~/$HOME}"
  [[ -n "$gi" ]] || gi="$HOME/.config/git/ignore"
  if [[ -f "$gi" ]] && grep -qxF "lefthook-local.yml" "$gi"; then
    note "-> global gitignore already covers lefthook-local.yml ($gi)"
  else
    mkdir -p "$(dirname "$gi")"
    printf 'lefthook-local.yml\n' >> "$gi"
    [[ -n "$(git config --global core.excludesFile 2>/dev/null || true)" ]] \
      || git config --global core.excludesFile "$gi"
    note "-> added lefthook-local.yml to global gitignore ($gi)"
  fi
}

chain_husky() { # $1 = target repo; append lefthook to husky hooks, never replace
  local target="$1" hook file
  note "-> husky detected -- chaining lefthook after it (not replacing)"
  for hook in pre-commit pre-push; do
    file="$target/.husky/$hook"
    if [[ -f "$file" ]] && grep -q "lefthook run $hook" "$file"; then
      continue
    fi
    printf 'lefthook run %s "$@"\n' "$hook" >> "$file"
    chmod +x "$file"
    note "-> chained lefthook into .husky/$hook"
  done
  echo "  NOTE: hooks stay husky-managed; lefthook runs as the last step of each."
}

# Global core.hooksPath is NOT a blocker when it holds CHAIN wrappers — files
# that delegate to $(git rev-parse --git-dir)/hooks/<hook> when it exists, so
# locally installed lefthook hooks still run through the chain.
global_hookspath_status() { # prints: none | chained | broken:<missing hooks>
  local gp missing="" hook file
  gp="$(git config --global core.hooksPath 2>/dev/null || true)"
  [[ -n "$gp" ]] || { echo "none"; return 0; }
  gp="${gp/#\~/$HOME}"
  for hook in pre-commit pre-push; do
    file="$gp/$hook"
    if [[ ! -f "$file" ]] || ! grep -q 'git rev-parse --git-dir' "$file"; then
      missing="$missing $hook"
    fi
  done
  if [[ -z "$missing" ]]; then echo "chained"; else echo "broken:${missing# }"; fi
}

local_tracked_hookspath() { # $1 = target repo; prints the repo-relative LOCAL
  # core.hooksPath dir when it is TRACKED (versioned hooks like .githooks);
  # fails otherwise. Installing lefthook stubs there would modify tracked files.
  local target="$1" lp
  lp="$(git -C "$target" config --local core.hooksPath 2>/dev/null || true)"
  [[ -n "$lp" ]] || return 1
  lp="${lp/#\~/$HOME}"
  case "$lp" in
    "$target"/*) lp="${lp#"$target"/}" ;;
    /*) return 1 ;;   # absolute path outside the repo: nothing tracked to protect
  esac
  [[ -n "$(git -C "$target" ls-files -- "$lp" 2>/dev/null)" ]] || return 1
  printf '%s\n' "$lp"
}

verify_tracked_hooks_dir_clean() { # $1 = target repo, $2 = tracked hooks dir
  # (repo-relative). Undo anything lefthook wrote into it: restore modified
  # tracked files, delete untracked stubs -- only files that mention lefthook.
  local target="$1" dir="$2" dirty line st path
  dirty="$(git -C "$target" status --porcelain -- "$dir" 2>/dev/null || true)"
  if [[ -z "$dirty" ]]; then
    note "-> tracked hooks dir $dir verified clean (git status)"
    return 0
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    st="${line:0:2}"; path="${line:3}"
    grep -q lefthook "$target/$path" 2>/dev/null || continue
    if [[ "$st" == "??" ]]; then
      rm -f "$target/$path"; note "-> removed lefthook stub $path from tracked hooks dir"
    else
      git -C "$target" checkout -- "$path" 2>/dev/null \
        && note "-> restored $path (lefthook had overwritten it)"
    fi
  done <<<"$dirty"
  dirty="$(git -C "$target" status --porcelain -- "$dir" 2>/dev/null || true)"
  if [[ -z "$dirty" ]]; then
    note "-> tracked hooks dir $dir verified clean (git status)"
  else
    bad "tracked hooks dir $dir still has changes after install -- review: git -C $target status -- $dir"
  fi
}

cleanup_team_autocreated_yml() { # $1 = target repo, $2 = lefthook.yml existed
  # before install (0/1). 'lefthook install' auto-creates lefthook.yml when the
  # repo has none ("Config not found, creating..."); in team mode that leaves a
  # committable file this tool never meant to add. Remove it when it is
  # untracked AND lefthook-made; a tracked one belongs to the project.
  local target="$1" existed="$2" yml="$1/lefthook.yml"
  [[ -f "$yml" ]] || return 0
  if git -C "$target" ls-files --error-unmatch lefthook.yml >/dev/null 2>&1; then
    note "-> project tracks its own lefthook.yml -- kept untouched; lefthook-local.yml extends it"
  elif [[ "$existed" == 0 ]] || grep -qi 'example usage' "$yml"; then
    rm -f "$yml"
    note "-> removed lefthook.yml auto-created by 'lefthook install' (team mode: config lives in lefthook-local.yml)"
  fi
}

wire_repo_hooks() { # $1 = target repo (absolute); full wiring of ONE repo, no exit
  local target="$1" team="$TEAM" cfg_file answer hookspath gitdir local_hp had_lefthook_yml=0
  AGENT_ACTIONS=""
  [[ -f "$target/lefthook.yml" ]] && had_lefthook_yml=1

  # solo vs team: flag wins; otherwise ask (non-interactive defaults to solo)
  if [[ "$team" == 0 && -t 0 ]]; then
    read -r -p "Does $(basename "$target") have a team (shared lefthook.yml)? [y/N] " answer
    [[ "$answer" == [yY]* ]] && team=1
  fi

  if [[ "$team" == 1 ]]; then
    cfg_file="$target/lefthook-local.yml"
    ensure_global_gitignore
  else
    cfg_file="$target/lefthook.yml"
  fi
  if [[ -f "$cfg_file" ]] && ! grep -qF "$REMOTE_URL" "$cfg_file"; then
    bad "$(basename "$cfg_file") exists and does not reference $REMOTE_URL -- merge this snippet manually:"
    echo "  remotes:"
    echo "    - git_url: $REMOTE_URL"
    echo "      ref: main"
    echo "      refetch_frequency: 24h"
    echo "      configs: [hooks/lefthook-base.yml]"
  else
    write_remotes_config "$cfg_file"
  fi

  hookspath="$(global_hookspath_status)"
  if [[ -d "$target/.husky" ]]; then
    chain_husky "$target"
  elif local_hp="$(local_tracked_hookspath "$target")"; then
    # repo-LOCAL core.hooksPath pointing at a TRACKED dir (versioned hooks):
    # never install stubs there -- lefthook would rewrite tracked files. Same
    # scoped override as the global-chained case: stubs go to .git/hooks.
    gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
    if ( cd "$target" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
        GIT_CONFIG_VALUE_0="$gitdir/hooks" lefthook install --force ); then
      note "-> local core.hooksPath ($local_hp) is tracked -- lefthook stubs installed in .git/hooks; the project's hooks in $local_hp stay intact"
    else
      bad "lefthook install --force failed -- see its message above; fix and re-run"
    fi
    verify_tracked_hooks_dir_clean "$target" "$local_hp"
    # honesty check: with a LOCAL core.hooksPath git only ever runs $local_hp --
    # the stubs in .git/hooks are dead code unless the project's hooks delegate
    local delegated=1 h
    for h in pre-commit pre-push; do
      hook_invokes_lefthook "$target" "$h" || delegated=0
    done
    if [[ "$delegated" == 0 ]]; then
      note "!! hooks NOT active in this repo: git uses the tracked hooksPath ($local_hp), so the lefthook stubs in .git/hooks are never invoked"
      note "   two ways out:"
      note "   1) PR a delegation line into the project's own hooks -- append to $local_hp/pre-commit and $local_hp/pre-push (matching hook name):"
      note '        command -v lefthook >/dev/null 2>&1 && lefthook run pre-commit "$@"'
      note "   2) skip consciously: this repo keeps only its own hooks (re-check any time with: flowkit hooks --verify)"
      agent_action "Hooks NOT active in this repo (tracked core.hooksPath $local_hp). Either PR the lefthook delegation line into $local_hp/pre-commit and $local_hp/pre-push, or record the conscious skip."
    fi
  elif [[ "$hookspath" == broken:* ]]; then
    bad "global core.hooksPath set but chain wrapper(s) missing for: ${hookspath#broken:} -- each wrapper must delegate to \$(git rev-parse --git-dir)/hooks/<hook>; add them and re-run"
  elif [[ "$hookspath" == "chained" ]]; then
    # lefthook installs into `git rev-parse --git-path hooks`, which honors the
    # GLOBAL core.hooksPath — a plain --force would clobber the chain wrappers.
    # Scope-override hooksPath to the local hooks dir so stubs land in
    # .git/hooks/, exactly where the wrappers delegate.
    gitdir="$(git -C "$target" rev-parse --absolute-git-dir)"
    if ( cd "$target" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath \
        GIT_CONFIG_VALUE_0="$gitdir/hooks" lefthook install --force ); then
      note "-> global hooksPath with chain wrappers: OK -- lefthook stubs in .git/hooks (invoked via the chain)"
    else
      bad "lefthook install --force failed -- see its message above; fix and re-run"
    fi
  elif ( cd "$target" && lefthook install ); then
    note "-> lefthook install done"
  else
    bad "lefthook install failed -- see its message above (e.g. a custom core.hooksPath); fix and re-run"
  fi

  [[ "$team" == 1 ]] && cleanup_team_autocreated_yml "$target" "$had_lefthook_yml"

  run_gitleaks_baseline "$target" "$team"
  # never stamped automatically: a generic fixed-length regex is a false-positive
  # decision only the project can make -- the agent block carries the nudge
  if [[ ! -f "$target/.gitleaks.toml" ]]; then
    agent_action "Project-specific secret formats (e.g. fixed-length CSPRNG tokens) are invisible to the central rules -- add a repo-local .gitleaks.toml (extend useDefault) with a rule for YOUR token format."
  fi
  ensure_flow_import "$target" "$team"
  ensure_ship_config_template "$target"
  check_agent_docs_fences "$target"
  if docs_is_published_site "$target"; then
    # agent guidance travels attached to the fence finding itself (see
    # check_agent_docs_fences) -- a second standalone line duplicated it
    note "-> docs/ looks like a PUBLISHED SITE (CNAME/index.html/_config.yml or a Pages workflow)"
  fi
  # the install ENDS with the effective-state verification -- no false "wired ok"
  LAST_VERIFY_RC=0
  verify_repo_hooks "$target" || LAST_VERIFY_RC=1
  if [[ "$LAST_VERIFY_RC" -ne 0 ]]; then
    VERIFY_FAILED=$((VERIFY_FAILED + 1))
    agent_action "flowkit hooks --verify FAILED for this repo -- hooks are not fully active; see the verify lines above (delegation PR or conscious skip)."
  fi
  print_agent_actions
}

list_child_repos() { # $1 = candidate workspace root; prints 1st-level dirs that are git repos
  local d
  for d in "$1"/*/; do
    [[ -e "${d}.git" ]] || continue
    git -C "${d%/}" rev-parse --git-dir >/dev/null 2>&1 && printf '%s\n' "${d%/}"
  done
}

install_repo() {
  local target child before name
  target="$(cd "$TARGET_REPO" 2>/dev/null && pwd)" || die "not a directory: $TARGET_REPO"
  git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $target"

  # --verify: effective-state check only, no wiring, exit 0/1
  if [[ "$VERIFY_ONLY" == 1 ]]; then
    if verify_repo_hooks "$target"; then exit 0; else exit 1; fi
  fi

  check_tool_versions

  local children=()
  while IFS= read -r child; do children+=("$child"); done < <(list_child_repos "$target")

  # plain repo (no git children) → wire it directly, previous behavior
  if [[ "${#children[@]}" -eq 0 ]]; then
    wire_repo_hooks "$target"
    if [[ "$PROBLEMS" -gt 0 ]]; then
      echo "-- $PROBLEMS problem(s) found"
      exit 1
    fi
    if [[ "$VERIFY_FAILED" -gt 0 ]]; then
      echo "-- wiring finished, but hooks are NOT fully active in $target -- see the verify report above."
    else
      echo "-- hooks wired into $target. First commit exercises them."
    fi
    exit 0
  fi

  # WORKSPACE: a git repo whose 1st-level children are git repos themselves.
  # Each child gets wired; the parent is skipped by default (workspace roots
  # carry their own no-commit locks) unless --include-parent.
  note "-> workspace detected: ${#children[@]} child repo(s) under $target"
  local targets=() results=()
  if [[ "$INCLUDE_PARENT" == 1 ]]; then
    targets+=("$target")
  else
    note "-> parent skipped (use --include-parent to wire it too)"
  fi
  targets+=("${children[@]}")

  for child in "${targets[@]}"; do
    name="$(basename "$child")"
    [[ "$child" == "$target" ]] && name="$name (parent)"
    before="$PROBLEMS"
    echo ""
    note "-- wiring $name"
    wire_repo_hooks "$child"
    if [[ "$PROBLEMS" -gt "$before" ]]; then
      results+=("$name|$((PROBLEMS - before)) problem(s)")
    elif [[ "$LAST_VERIFY_RC" -ne 0 ]]; then
      results+=("$name|hooks NOT active (verify failed)")
    else
      results+=("$name|ok")
    fi
  done

  echo ""
  echo "-- workspace report ($target)"
  printf '  %-32s %s\n' "repo" "result"
  printf '  %-32s %s\n' "----" "------"
  for child in "${results[@]}"; do
    printf '  %-32s %s\n' "${child%%|*}" "${child##*|}"
  done
  if [[ "$PROBLEMS" -gt 0 ]]; then
    echo "-- $PROBLEMS problem(s) found"
    exit 1
  fi
  if [[ "$VERIFY_FAILED" -gt 0 ]]; then
    echo "-- wired ${#targets[@]} repo(s); hooks NOT fully active in $VERIFY_FAILED of them -- see the verify lines above."
  else
    echo "-- hooks wired into ${#targets[@]} repo(s). First commit in each exercises them."
  fi
  exit 0
}
