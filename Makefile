# frozen_string_literal: true

.PHONY: help test lint lint-js lint-ruby lintfix lintfix-js lintfix-ruby setup dev clean frontend-setup

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
	@echo "Ruby server: http://localhost:3000"
	@echo "Astro dev server: http://localhost:3001 (with live reload)"
	@echo "Main development URL: http://localhost:3001"
	@echo ""
	@bin/dev

dev-ruby: ## Start Ruby server only
	@bin/dev-ruby

dev-frontend: ## Start Astro dev server only
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

test-frontend-smoke: ## Run frontend smoke tests (Playwright)
	@cd frontend && npm run test:smoke

lint: lint-ruby lint-js ## Run all linters (Ruby + Frontend) - errors when issues found
	@echo "All linting complete!"

lint-ruby: ## Run Ruby linter (RuboCop) - errors when issues found
	@echo "Running RuboCop linting..."
	bundle exec rubocop
	@echo "Ruby linting complete!"

lint-js: ## Run JavaScript/Frontend linter (Prettier) - errors when issues found
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

clean: ## Clean temporary files
	@rm -rf tmp/rack-cache-* coverage/
	@cd frontend && rm -rf dist/ .astro/ node_modules/
	@echo "Clean complete!"

frontend-setup: ## Setup frontend dependencies
	@echo "Setting up frontend dependencies..."
	@cd frontend && npm install
	@echo "Frontend setup complete!"
