# frozen_string_literal: true

.PHONY: help test lint lint-js lint-ruby lintfix lintfix-js lintfix-ruby setup dev clean frontend-setup check-frontend quick-check ready yard-verify-public-docs openapi openapi-verify openapi-client openapi-client-verify openapi-lint openapi-lint-redocly openapi-lint-spectral openai-lint-spectral test-frontend-e2e

# Default target
help: ## Show this help message
	@echo "html2rss-web Development Commands"
	@echo "================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Full development setup
	@echo "Setting up development environment..."
	bundle install
	@if [ ! -f .env ]; then \
		cp .env.example .env 2>/dev/null || echo "RACK_ENV=development" > .env; \
		echo "Created .env file"; \
	fi
	@mkdir -p tmp/rack-cache-body tmp/rack-cache-meta
	@echo "Setting up frontend..."
	@cd frontend && npm install
	@echo "Setup complete!"

dev: ## Start development server with live reload
	@echo "Starting html2rss-web development environment..."
	@bin/dev

dev-ruby: ## Start Ruby server only
	@bin/dev-ruby

dev-frontend: ## Start frontend dev server only
	@cd frontend && npm run dev

test: ## Run all tests (Ruby + Frontend)
	bundle exec rspec
	@cd frontend && npm run test:ci

test-ruby: ## Run Ruby tests only
	bundle exec rspec

test-frontend: ## Run frontend tests only
	@cd frontend && npm run test:ci

test-frontend-unit: ## Run frontend unit tests only
	@cd frontend && npm run test:unit

test-frontend-contract: ## Run frontend contract tests only
	@cd frontend && npm run test:contract

test-frontend-e2e: ## Run frontend Playwright smoke tests
	@cd frontend && npm run test:e2e

check-frontend: ## Run frontend typecheck, format, and test checks
	$(MAKE) lint-js
	$(MAKE) test-frontend


lint: lint-ruby lint-js ## Run all linters (Ruby + Frontend) - errors when issues found
	@echo "All linting complete!"

lint-ruby: ## Run Ruby linter (RuboCop) - errors when issues found
	@echo "Running RuboCop linting..."
	bundle exec rubocop
	@echo "Running Zeitwerk eager-load check..."
	bundle exec rake zeitwerk:verify
	@echo "Running YARD public-method docs check..."
	bundle exec rake yard:verify_public_docs
	@echo "Ruby linting complete!"

lint-js: ## Run JavaScript/Frontend linter (Prettier) - errors when issues found
	@echo "Running TypeScript typecheck..."
	@cd frontend && npm run typecheck
	@echo "Running Prettier format check..."
	@cd frontend && npm run format:check
	@echo "JavaScript linting complete!"

lintfix: lintfix-ruby lintfix-js ## Auto-fix all linting issues (Ruby + Frontend)
	@echo "All lintfix complete!"

lintfix-ruby: ## Auto-fix Ruby linting issues
	@echo "Running RuboCop auto-correct..."
	-bundle exec rubocop --auto-correct
	@echo "Ruby lintfix complete!"

lintfix-js: ## Auto-fix JavaScript/Frontend linting issues
	@echo "Running Prettier formatting..."
	@cd frontend && npm run format
	@echo "JavaScript lintfix complete!"

quick-check: ## Fast local checks (Ruby lint/docs + frontend format/typecheck)
	@echo "Running quick checks..."
	$(MAKE) lint-ruby
	$(MAKE) lint-js
	@echo "Quick checks complete!"

ready: ## Pre-commit gate (quick checks + RSpec)
	@echo "Running pre-commit checks..."
	$(MAKE) quick-check
	bundle exec rspec
	@echo "Pre-commit checks complete!"

yard-verify-public-docs: ## Verify essential YARD docs for all public methods in app/
	bundle exec rake yard:verify_public_docs

openapi: ## Regenerate public/openapi.yaml from request specs
	bundle exec rake openapi:generate

openapi-verify: ## Regenerate OpenAPI and fail if public/openapi.yaml or frontend client is stale
	bundle exec rake openapi:verify
	$(MAKE) openapi-client-verify

openapi-client: ## Generate frontend OpenAPI client/types from public/openapi.yaml
	@cd frontend && npm run openapi:generate

openapi-client-verify: ## Generate frontend OpenAPI client and fail if generated files are stale
	@cd frontend && npm run openapi:verify

openapi-lint: openapi-lint-redocly openapi-lint-spectral ## Lint public/openapi.yaml with Redocly and Spectral

openapi-lint-redocly: ## Lint OpenAPI using Redocly recommended rules
	npx --yes @redocly/cli lint --config .redocly.yaml public/openapi.yaml

openapi-lint-spectral: ## Lint OpenAPI using Spectral OAS rules
	npx --yes @stoplight/spectral-cli lint --ruleset .spectral.yaml public/openapi.yaml

openai-lint-spectral: openapi-lint-spectral ## Alias for openapi-lint-spectral

clean: ## Clean temporary files
	@rm -rf tmp/rack-cache-* coverage/
	@cd frontend && rm -rf dist/ node_modules/
	@echo "Clean complete!"

frontend-setup: ## Setup frontend dependencies
	@echo "Setting up frontend dependencies..."
	@cd frontend && npm install
	@echo "Frontend setup complete!"
