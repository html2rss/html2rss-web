# frozen_string_literal: true

.PHONY: help test lint fix setup dev clean frontend-setup frontend-format frontend-format-check frontend-lint

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

test-frontend-integration: ## Run frontend integration tests only
	@cd frontend && npm run test:integration

lint: ## Run linter
	bundle exec rubocop

fix: ## Auto-fix linting issues
	bundle exec rubocop -a

clean: ## Clean temporary files
	@rm -rf tmp/rack-cache-* coverage/
	@cd frontend && rm -rf dist/ .astro/ node_modules/
	@echo "Clean complete!"

frontend-setup: ## Setup frontend dependencies
	@echo "Setting up frontend dependencies..."
	@cd frontend && npm install
	@echo "Frontend setup complete!"

frontend-format: ## Format frontend code
	@echo "Formatting frontend code..."
	@cd frontend && npm run format
	@echo "Frontend formatting complete!"

frontend-format-check: ## Check frontend code formatting
	@echo "Checking frontend code formatting..."
	@cd frontend && npm run format:check

frontend-lint: frontend-format-check ## Lint frontend code (formatting check)
	@echo "Frontend linting complete!"
