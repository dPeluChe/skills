#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks are literal markdown in the fixture files
# A week of conventional commits around a search feature, plus uncommitted UI work.
set -euo pipefail
g() { git -c user.name=Dev -c user.email=dev@example.test "$@"; }
ago() { date -v-"$1"d +%Y-%m-%dT10:00:00 2>/dev/null || date -d "$1 days ago" +%Y-%m-%dT10:00:00; }
c() { local d; d="$(ago "$1")"; GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" g commit -qm "$2"; }
g init -q -b main .
mkdir -p src/ui docs
printf '# TASK_TODO\n- [ ] Busqueda (API + UI)\n- [ ] Filtros por fecha\n' > docs/TASK_TODO.md
echo 'export const items = [];' > src/items.js
g add -A; c 20 "feat: items list"
echo 'export const search = (q) => q;' > src/search.js; g add -A; c 6 "feat(api): add /search endpoint"
echo 'export const search = (q) => (q ? q : []);' > src/search.js; g add -A; c 4 "fix(search): handle empty query"
echo '{"deps":"bumped"}' > package.json; g add -A; c 3 "chore: bump deps"
echo '// search box' > src/ui/SearchBox.js; g add -A; c 1 "feat(ui): search box wip"
echo '// debounce input, results list pending' >> src/ui/SearchBox.js
