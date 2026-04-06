.PHONY: test test-scripts test-integration lint check help

# ── Default ──────────────────────────────────────────────────────────────────
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

# ── Testing ──────────────────────────────────────────────────────────────────
test: test-scripts ## Run all offline tests

test-scripts: ## Test configure-runner.sh and install-skills.sh
	@./scripts/test-scripts.sh

test-integration: ## Smoke-test installed runners (needs API keys)
	@./scripts/test-integration.sh

# ── Linting ──────────────────────────────────────────────────────────────────
lint: ## Lint shell scripts with shellcheck
	@shellcheck scripts/*.sh

# ── Pre-commit check ─────────────────────────────────────────────────────────
check: lint test ## Run lint + tests (use before committing)
