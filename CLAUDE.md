# CLAUDE.md

@~/.agents/skills/FLOW_CLAUDE.md

## ship config

```yaml
lint: shellcheck scripts/install.sh scripts/test-hooks.sh bin/flowkit scripts/lib/*.sh scripts/tests/*.sh hooks/harness/*.sh
# typecheck: (n/a -- shell)
# build: (n/a -- no build artifact)
test: bash scripts/test-hooks.sh
merge_policy: auto        # practica real: suite verde = merge (los agentes ya lo hacen)
loc_limit: 500
simplify: 500
```
