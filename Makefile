# dPeluChe/skills — thin wrappers over scripts/. `make help` lists everything.
.DEFAULT_GOAL := help

REPO ?=
TEAM ?=

.PHONY: help install check prune hooks test

help: ## list available targets
	@awk -F':.*## ' '/^[a-z-]+:.*## / { printf "  make %-24s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install: ## sync all skills into the symlink chain (~/.claude → ~/.agents → repo)
	./scripts/install.sh

check: ## doctor mode — validate every link, change nothing (exit 0/1)
	./scripts/install.sh --check

prune: ## sync + remove orphan links left by renamed/deleted skills
	./scripts/install.sh --prune

hooks: ## wire centralized git hooks into a repo: make hooks REPO=/path [TEAM=1]
ifeq ($(REPO),)
	$(error REPO is required: make hooks REPO=/path/to/repo [TEAM=1])
endif
	./scripts/install.sh --repo $(REPO) $(if $(TEAM),--team)

test: ## run the hooks test harness (shellcheck + wrapper fixtures)
	bash scripts/test-hooks.sh
