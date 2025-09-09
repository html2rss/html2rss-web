# frozen_string_literal: true

.PHONY: help test lint fix setup dev clean

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
	@echo "Setup complete!"

dev: ## Start development server
	@echo "Starting development server..."
	@echo "Server will be available at: http://localhost:3000"
	@echo "Press Ctrl+C to stop"
	@bin/dev

test: ## Run tests
	bundle exec rspec

lint: ## Run linter
	bundle exec rubocop

fix: ## Auto-fix linting issues
	bundle exec rubocop -a

clean: ## Clean temporary files
	@rm -rf tmp/rack-cache-* coverage/
	@echo "Clean complete!"
