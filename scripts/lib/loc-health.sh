# shellcheck shell=bash
# shellcheck disable=SC2154  # globals come from install.sh
# loc-health: repo-wide file-size audit (sourced by install.sh). The pre-commit
# loc-warning covers the diff; this covers the tree. Advisory, never blocks.

_loc_limit() { # $1 = repo root; prints the numeric limit (default 500)
  local raw
  raw="$(fk_config_get loc_limit "$1")"
  [[ "$raw" =~ ^[0-9]+$ ]] && printf '%s\n' "$raw" || printf '500\n'
}

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
    printf '%s\n' "$f" | grep -qiE "$FK_LOC_SKIP" && continue
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
    echo "  Advisory only -- this never blocks. Per-repo limit: loc_limit in CLAUDE.md preship config."
  else
    echo "  ok no files over $limit LOC"
    echo "--"
    echo "ok loc-health: every file within the $limit-LOC rule"
  fi
  exit 0
}
