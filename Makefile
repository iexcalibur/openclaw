SHELL := /bin/bash

.DEFAULT_GOAL := help

FORK_URL ?= https://github.com/iexcalibur/openclaw.git
UPSTREAM_URL ?= https://github.com/openclaw/openclaw.git
BASE_BRANCH ?= main
WORK_BRANCH ?= codex/link_main
GIT_USER_NAME ?= iexcalibur
GIT_USER_EMAIL ?= shubhamkannojia10@gmail.com
PNPM ?= pnpm

.PHONY: help git-setup sync-main branch status install build test check tsgo format format-fix audit dev

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

git-setup: ## Configure git remotes/identity, sync main, and create work branch.
	@if [ ! -d .git ]; then git init; fi
	git config user.name "$(GIT_USER_NAME)"
	git config user.email "$(GIT_USER_EMAIL)"
	@if git remote get-url origin >/dev/null 2>&1; then \
		git remote set-url origin "$(FORK_URL)"; \
	else \
		git remote add origin "$(FORK_URL)"; \
	fi
	@if git remote get-url upstream >/dev/null 2>&1; then \
		git remote set-url upstream "$(UPSTREAM_URL)"; \
	else \
		git remote add upstream "$(UPSTREAM_URL)"; \
	fi
	git fetch origin "$(BASE_BRANCH)"
	git checkout -B "$(BASE_BRANCH)" "origin/$(BASE_BRANCH)"
	git checkout -B "$(WORK_BRANCH)" "$(BASE_BRANCH)"

sync-main: ## Update local main from origin and rebase work branch.
	git fetch origin "$(BASE_BRANCH)"
	git checkout "$(BASE_BRANCH)"
	git pull --ff-only origin "$(BASE_BRANCH)"
	git checkout "$(WORK_BRANCH)"
	git rebase "$(BASE_BRANCH)"

branch: ## Recreate/switch to the work branch from main.
	git checkout "$(BASE_BRANCH)"
	git checkout -B "$(WORK_BRANCH)" "$(BASE_BRANCH)"

status: ## Show current branch and git remotes.
	git status --short --branch
	git remote -v

install: ## Install dependencies.
	$(PNPM) install

build: ## Build project artifacts.
	$(PNPM) build

test: ## Run test suite.
	$(PNPM) test

check: ## Run full lint/type checks.
	$(PNPM) check

tsgo: ## Run TypeScript checks.
	$(PNPM) tsgo

format: ## Check formatting.
	$(PNPM) format

format-fix: ## Apply formatting fixes.
	$(PNPM) format:fix

audit: ## Run dependency vulnerability audit.
	$(PNPM) audit

dev: ## Start development CLI runner.
	$(PNPM) dev
