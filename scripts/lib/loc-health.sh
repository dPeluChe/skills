# shellcheck shell=bash
# shellcheck disable=SC2154  # globals come from install.sh
# ── loc-health: file-size audit (the one mechanical dev rule worth automating) ─
# Sourced by scripts/install.sh (the entrypoint); never executed directly.
#
# Team rule (dpeluche.dev docs/profile/13-development-rules.md): 400-500 LOC max
# per file. The OTHER rules (reuse-before-write, anti-N+1, materialize) are
# judgment and stay in the doc; THIS one is mechanical and verifiable, so it is
# the one that earns automation. Advisory everywhere -- never blocks.
#
# Two surfaces: the pre-commit hook warns about files THIS diff grows past the
# limit (in hooks/lefthook-base.yml, diff-scoped); `flowkit loc-health` audits
# the whole repo on demand (here).

# loc_limit from the repo's CLAUDE.md "## ship config" block; default 500. Same
# block the pre-push gate reads for lint/typecheck -- one per-repo source.
_loc_limit() { # $1 = repo root; prints the numeric limit
  local root="$1" raw=""
  if [[ -f "$root/CLAUDE.md" ]]; then
    # shellcheck disable=SC2016  # backtick fences in the yaml block are literal, not expansions
    raw="$(sed -n '/^## ship config$/,/^## /p' "$root/CLAUDE.md" 2>/dev/null \
      | sed -n '/^```yaml$/,/^```$/p' | sed -n 's/^loc_limit:[[:space:]]*//p' \
      | sed 's/[[:space:]]*#.*$//' | tr -d '[:space:]' | head -1)"
  fi
  [[ "$raw" =~ ^[0-9]+$ ]] && printf '%s\n' "$raw" || printf '500\n'
}

# files that are NOT code-to-split -- lockfiles, minified, generated, maps,
# snapshots, docs (a long CHANGELOG/guide is not a design smell; doc hygiene is
# doctos' job), binaries. loc-health is the CODE-file size rule.
_LOC_SKIP='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|composer\.lock|poetry\.lock|Gemfile\.lock)$|\.min\.|\.map$|\.snap$|_generated|/generated/|\.d\.ts$|\.(md|mdx|markdown|rst|adoc)$|\.(svg|png|jpe?g|gif|webp|ico|pdf|woff2?|ttf|eot|mp4|mov|zip|gz|tgz|lock)$'

run_loc_health() {
  local target="${1:-.}"
  target="$(cd "$target" 2>/dev/null && pwd)" || die "loc-health: not a directory: ${1:-.}"
  local limit; limit="$(_loc_limit "$target")"
  echo "-- loc-health ($target, limit ${limit} LOC)"

  # tracked files (respects .gitignore); fall back to a find walk outside git.
  local -a files=(); local f
  if git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r f; do files+=("$f"); done < <(git -C "$target" ls-files 2>/dev/null)
  else
    while IFS= read -r f; do files+=("${f#"$target"/}"); done < <(find "$target" \
      -type d \( -name node_modules -o -name .git -o -name dist -o -name build \) -prune \
      -o -type f -print 2>/dev/null)
  fi

  local over="" n
  for f in ${files[@]+"${files[@]}"}; do
    printf '%s\n' "$f" | grep -qiE "$_LOC_SKIP" && continue
    [[ -f "$target/$f" ]] || continue
    n="$(wc -l < "$target/$f" 2>/dev/null | tr -d ' ')"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    [[ "$n" -gt "$limit" ]] && over+="$n	$f"$'\n'
  done

  local over_n
  over_n="$(printf '%s' "$over" | grep -c . || true)"
  if [[ "$over_n" -gt 0 ]]; then
    echo "  ! $over_n file(s) over $limit LOC (largest first):"
    printf '%s' "$over" | sort -rn | head -40 | while IFS='	' read -r n f; do
      [[ -n "$f" ]] && printf '      %6s  %s\n' "$n" "$f"
    done
    echo "--"
    echo "ALERT: files above the $limit-LOC rule -- consider splitting the largest."
    echo "  Advisory only -- this never blocks. Per-repo limit: loc_limit in CLAUDE.md ship config."
  else
    echo "  ok no files over $limit LOC"
    echo "--"
    echo "ok loc-health: every file within the $limit-LOC rule"
  fi
  exit 0
}
