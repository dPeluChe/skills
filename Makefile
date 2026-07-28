# dPeluChe/skills — thin wrappers over scripts/. `make help` lists everything.
.DEFAULT_GOAL := help

REPO ?=
TEAM ?=

.PHONY: help install check prune hooks upgrade test

help: ## list available targets
	@awk -F':.*## ' '/^[a-z-]+:.*## / { printf "  make %-24s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "  after 'make install', the flowkit CLI is available globally: flowkit help"

install: ## sync all skills into the symlink chain (~/.claude → ~/.agents → repo) + ~/bin/flowkit
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

upgrade: ## report lefthook/gitleaks vs minimums (+ brew outdated) and this clone vs origin/main (exit 1 if pending)
	./scripts/install.sh --upgrade

test: ## run the hooks test harness (shellcheck + wrapper fixtures)
	bash scripts/test-hooks.sh
