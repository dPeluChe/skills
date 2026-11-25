#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks are literal markdown in the fixture files
# A feature branch whose configured lint fails; test passes.
set -euo pipefail
g() { git -c user.name=Dev -c user.email=dev@example.test "$@"; }
g init -q -b main .
mkdir -p scripts src
cat > CLAUDE.md <<'MD'
# CLAUDE.md

## preship config

```yaml
lint: bash scripts/lint.sh
test: bash scripts/test.sh
merge_policy: ask
```
MD
printf '#!/usr/bin/env bash\necho "src/search.js:3:7 warning  x is assigned a value but never used  no-unused-vars"\necho "1 problem (0 errors, 1 warning)"\nexit 1\n' > scripts/lint.sh
printf '#!/usr/bin/env bash\necho "3 passed"\n' > scripts/test.sh
echo 'export const items = [];' > src/items.js
g add -A; g commit -qm "chore: init"
g checkout -qb feat/search
printf 'export function search(q) {\n  if (!q) return [];\n  const x = 1;\n  return [q];\n}\n' > src/search.js
g add -A; g commit -qm "feat: search"
