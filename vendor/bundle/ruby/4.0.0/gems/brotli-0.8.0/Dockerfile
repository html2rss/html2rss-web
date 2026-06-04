ARG GCC_VERSION=14
FROM gcc:${GCC_VERSION}

ARG USE_SYSTEM_BROTLI=true

# Install Ruby and development dependencies
RUN apt-get update && apt-get install -y \
    git \
    libbrotli-dev \
    pkg-config \
    ruby \
    ruby-dev \
    && rm -rf /var/lib/apt/lists/*

# Verify GCC version
RUN gcc --version

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Install bundler and dependencies
RUN gem install bundler
RUN bundle install

# Build and test
RUN if [ "${USE_SYSTEM_BROTLI}" = "true" ]; then \
        echo "Building with system Brotli" && \
        bundle exec rake compile; \
    else \
        echo "Building with vendor Brotli" && \
        bundle exec rake compile -- --enable-vendor; \
    fi
RUN bundle exec rake test

CMD ["bash"]
