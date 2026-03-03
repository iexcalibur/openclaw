SHELL := /bin/bash

.DEFAULT_GOAL := help

FORK_URL ?= https://github.com/iexcalibur/openclaw.git
UPSTREAM_URL ?= https://github.com/openclaw/openclaw.git
BASE_BRANCH ?= main
WORK_BRANCH ?= codex/link_main
GIT_USER_NAME ?= iexcalibur
GIT_USER_EMAIL ?= shubhamkannojia10@gmail.com
PNPM ?= pnpm
DEV_ARGS ?= gateway
TELEGRAM_TOKEN ?= $(TELEGRAM_BOT_TOKEN)
PAIR_CODE ?=
TARGET ?=
MESSAGE ?= hello
MODEL ?= $(ANTHROPIC_MODEL)
NODE_BIN ?= $(firstword $(wildcard /usr/local/opt/node@22/bin/node /opt/homebrew/opt/node@22/bin/node $(HOME)/.nvm/versions/node/v22*/bin/node $(HOME)/.nvm/versions/node/*/bin/node /usr/local/bin/node /opt/homebrew/bin/node))
NODE_DIR := $(if $(NODE_BIN),$(dir $(NODE_BIN)))
PATH_FALLBACK ?= $(NODE_DIR):/opt/homebrew/bin:/usr/local/bin:$(HOME)/Library/pnpm:$(HOME)/.volta/bin:$(HOME)/.local/bin
PNPM_RUN := env PATH="$(PATH_FALLBACK):$$PATH" $(PNPM)
OPENCLAW_ENTRY ?= dist/entry.js
OPENCLAW_RUN := env PATH="$(PATH_FALLBACK):$$PATH" "$(NODE_BIN)" $(OPENCLAW_ENTRY)

.PHONY: help node-check git-setup sync-main branch status install build test check tsgo format format-fix audit dev setup gateway gateway-strict health doctor doctor-fix model-show model-set channels-status telegram-add pairing-list pairing-approve telegram-test-send

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

node-check: ## Verify Node.js >= 22.12.0.
	@if [ -z "$(strip $(NODE_BIN))" ]; then \
		echo "Node.js not found in common locations."; \
		echo "Set NODE_BIN explicitly, e.g. make node-check NODE_BIN=/path/to/node"; \
		exit 1; \
	fi
	@echo "Using node: $(NODE_BIN)"
	@env PATH="$(PATH_FALLBACK):$$PATH" node -e "const [major, minor] = process.version.slice(1).split('.').map(Number); if (major < 22 || (major === 22 && minor < 12)) { console.error('OpenClaw requires Node 22.12+. Current:', process.version); process.exit(1); } console.log('Node', process.version, 'OK');"

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
	$(PNPM_RUN) install

build: ## Build project artifacts.
	$(PNPM_RUN) build

test: ## Run test suite.
	$(PNPM_RUN) test

check: ## Run full lint/type checks.
	$(PNPM_RUN) check

tsgo: ## Run TypeScript checks.
	$(PNPM_RUN) tsgo

format: ## Check formatting.
	$(PNPM_RUN) format

format-fix: ## Apply formatting fixes.
	$(PNPM_RUN) format:fix

audit: ## Run dependency vulnerability audit.
	$(PNPM_RUN) audit

dev: ## Start OpenClaw (default: gateway). Override with DEV_ARGS, e.g. make dev DEV_ARGS="tui".
	$(OPENCLAW_RUN) $(DEV_ARGS)

setup: ## Run first-time OpenClaw setup wizard (creates local config/state).
	$(OPENCLAW_RUN) setup

gateway: ## Start gateway (bootstrap mode for first run; allows missing gateway.mode).
	$(OPENCLAW_RUN) gateway --allow-unconfigured

gateway-strict: ## Start gateway with strict config checks (requires gateway.mode=local).
	$(OPENCLAW_RUN) gateway

health: ## Check gateway health.
	$(OPENCLAW_RUN) health

doctor: ## Run diagnostics and suggested fixes.
	$(OPENCLAW_RUN) doctor

doctor-fix: ## Run diagnostics and auto-apply safe fixes.
	$(OPENCLAW_RUN) doctor --fix

model-show: ## Show current default model.
	@if ! $(OPENCLAW_RUN) config get agents.defaults.model.primary; then \
		echo "agents.defaults.model.primary is not set. Falling back to anthropic/claude-opus-4-6."; \
	fi

model-set: ## Set default model from MODEL (or ANTHROPIC_MODEL). Auto-prefixes anthropic/ when provider is missing.
	@model="$(strip $(MODEL))"; \
	if [ -z "$$model" ] && [ -f .env ]; then \
		model="$$(awk -F= '/^[[:space:]]*ANTHROPIC_MODEL[[:space:]]*=/{sub(/^[^=]*=[[:space:]]*/, "", $$0); print $$0; exit}' .env | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$$//; s/^"//; s/"$$//')"; \
	fi; \
	if [ -z "$$model" ]; then \
		echo "Missing MODEL (or ANTHROPIC_MODEL)."; \
		echo "Usage: make model-set MODEL=anthropic/claude-haiku-4-5-20251001"; \
		exit 1; \
	fi; \
	case "$$model" in \
		*/*) model_ref="$$model" ;; \
		*) model_ref="anthropic/$$model" ;; \
	esac; \
	echo "Setting default model: $$model_ref"; \
	$(OPENCLAW_RUN) models set "$$model_ref"

channels-status: ## Show connected channel status with probes.
	$(OPENCLAW_RUN) channels status --probe

telegram-add: ## Add Telegram account using TELEGRAM_TOKEN env (or TELEGRAM_BOT_TOKEN).
	@if [ -z "$(strip $(TELEGRAM_TOKEN))" ]; then \
		echo "Missing TELEGRAM_TOKEN (or TELEGRAM_BOT_TOKEN)."; \
		echo "Usage: make telegram-add TELEGRAM_TOKEN=<bot_token>"; \
		exit 1; \
	fi
	$(OPENCLAW_RUN) channels add --channel telegram --token "$(TELEGRAM_TOKEN)"

pairing-list: ## List pending Telegram pairing codes.
	$(OPENCLAW_RUN) pairing list telegram

pairing-approve: ## Approve Telegram pairing code. Usage: make pairing-approve PAIR_CODE=<code>
	@if [ -z "$(strip $(PAIR_CODE))" ]; then \
		echo "Missing PAIR_CODE."; \
		echo "Usage: make pairing-approve PAIR_CODE=<code>"; \
		exit 1; \
	fi
	$(OPENCLAW_RUN) pairing approve telegram "$(PAIR_CODE)"

telegram-test-send: ## Send a test Telegram message. Usage: make telegram-test-send TARGET=<chat_id> [MESSAGE='hi']
	@if [ -z "$(strip $(TARGET))" ]; then \
		echo "Missing TARGET (telegram chat id or @username)."; \
		echo "Usage: make telegram-test-send TARGET=<chat_id> MESSAGE='hello'"; \
		exit 1; \
	fi
	$(OPENCLAW_RUN) message send --channel telegram --target "$(TARGET)" --message "$(MESSAGE)"
