FROM ruby:4.0.1-alpine3.23

SHELL ["/bin/sh", "-o", "pipefail", "-c"]

RUN apk add --no-cache \
    bash \
    build-base \
    curl \
    git \
    libxml2-dev \
    libxslt-dev \
    nodejs \
    npm \
    openssl-dev \
    python3 \
    yaml-dev \
    tzdata

RUN if ! command -v corepack >/dev/null 2>&1; then npm install -g corepack; fi \
  && corepack enable \
  && corepack prepare "pnpm@latest" --activate

ARG USER=vscode
ARG UID=1000
ARG GID=1000

RUN addgroup -g "$GID" "$USER" \
  && adduser -D -G "$USER" -u "$UID" "$USER"

WORKDIR /workspace
RUN chown -R "$USER":"$USER" /workspace

ENV BUNDLE_PATH=/usr/local/bundle

USER "$USER"

EXPOSE 4000

CMD ["sleep", "infinity"]
