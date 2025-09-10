#!/bin/bash
set -e

echo "Setting up html2rss-web development environment..."

# Install dependencies
bundle install
cd frontend && npm install && cd ..

# Create .env if missing
if [ ! -f .env ]; then
  cat >.env <<EOF
RACK_ENV=development
HEALTH_CHECK_USERNAME=dev
HEALTH_CHECK_PASSWORD=dev
AUTO_SOURCE_ENABLED=true
AUTO_SOURCE_USERNAME=dev
AUTO_SOURCE_PASSWORD=dev
AUTO_SOURCE_ALLOWED_ORIGINS=localhost:3000
EOF
fi

# Create directories
mkdir -p tmp/rack-cache-body tmp/rack-cache-meta

# Build frontend
cd frontend && npm run build && cd ..

echo "Setup complete! Run 'make dev' to start the server."
