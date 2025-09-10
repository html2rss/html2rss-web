FROM mcr.microsoft.com/devcontainers/ruby:3.4-bullseye

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs

# Install system dependencies
RUN apt-get update && apt-get install -y \
  build-essential \
  git \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Install development gems
RUN gem install rubocop

# Install global npm packages
RUN npm install -g prettier

# Create vscode user
RUN groupadd --gid 1000 vscode \
  && useradd --uid 1000 --gid vscode --shell /bin/bash --create-home vscode

# Set up workspace
WORKDIR /workspace
RUN chown -R vscode:vscode /workspace

# Switch to vscode user
USER vscode

# Set up environment
RUN echo 'export BUNDLE_PATH="/usr/local/bundle"' >> ~/.bashrc

# Expose port
EXPOSE 3000

# Keep container running
CMD ["sleep", "infinity"]
