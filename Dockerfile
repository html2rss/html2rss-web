FROM node:22-alpine@sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914 AS node

FROM node AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package.json frontend/pnpm-lock.yaml frontend/pnpm-workspace.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm run build

FROM ruby:4.0.8-alpine3.24@sha256:e10c6cbfa9c0adf740c3c1d4d142d5b833b7901536f9968ce5925a6f3f6d0c14 AS ruby

FROM ruby AS dev

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3018
RUN apk add --no-cache \
  bash \
  build-base \
  chromium \
  curl \
  git \
  harfbuzz \
  libxml2-dev \
  libxslt-dev \
  nss \
  openssl-dev \
  python3 \
  ttf-freefont \
  yaml-dev \
  tzdata

COPY --from=node /usr/local/bin/node /usr/local/bin/corepack /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
# COPY materializes corepack as a file; restore the upstream symlink so dist/lib resolves.
RUN ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

ENV BUNDLE_PATH=/usr/local/bundle \
  COREPACK_HOME=/usr/local/share/corepack

COPY frontend/package.json /tmp/package.json
RUN corepack enable \
  && corepack prepare "$(node -p "require('/tmp/package.json').packageManager")" --activate \
  && rm /tmp/package.json

ARG USER=dev
ARG UID=1000
ARG GID=1000

RUN addgroup -g "$GID" "$USER" \
  && adduser -D -G "$USER" -u "$UID" "$USER" \
  && mkdir -p /workspace /usr/local/bundle /usr/local/share/corepack \
  && chown -R "$USER":"$USER" /workspace /usr/local/bundle /usr/local/share/corepack

WORKDIR /workspace

USER 1000

EXPOSE 4000 4001

CMD ["sleep", "infinity"]

FROM ruby AS builder

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

WORKDIR /app
COPY Gemfile Gemfile.lock ./

# hadolint ignore=SC2046
RUN apk add --no-cache \
  'gcc>=12' \
  'git>=2' \
  'libc-dev>=0.7' \
  'make>=4' \
  'openssl=~3' \
  'openssl-dev=~3' \
  'libxml2-dev>=2' \
  'libxslt-dev>=1' \
  && gem install bundler:$(tail -1 Gemfile.lock | tr -d ' ') \
  && bundle config set --local without 'development test' \
  && bundle install --retry=5 --jobs=$(nproc) \
  && bundle binstubs bundler html2rss falcon \
  && bundle clean --force \
  && rm -rf /usr/local/bundle/cache \
    /usr/local/bundle/bundler/gems/*/.git \
    /usr/local/bundle/cache/bundler/git

FROM ruby AS runtime

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

ARG BUILD_TAG
ARG GIT_SHA

ENV PORT=4000 \
  RACK_ENV=production \
  RUBY_YJIT_ENABLE=1 \
  BUILD_TAG=${BUILD_TAG} \
  GIT_SHA=${GIT_SHA}

EXPOSE $PORT

HEALTHCHECK --interval=30m --timeout=60s --start-period=5s \
  CMD ["/app/bin/docker-healthcheck"]

ARG USER=html2rss
ARG UID=991
ARG GID=991

RUN apk add --no-cache \
  'ca-certificates>=2024' \
  'tzdata>=2024' \
  'zlib>=1.3.2-r0' \
  && addgroup --gid "$GID" "$USER" \
  && adduser \
  --disabled-password \
  --gecos "" \
  --home "/app" \
  --ingroup "$USER" \
  --no-create-home \
  --uid "$UID" "$USER" \
  && mkdir -p /app \
  && chown "$USER":"$USER" -R /app

WORKDIR /app

USER 991

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --chown=$USER:$USER bin/docker-healthcheck ./bin/docker-healthcheck
COPY --chown=$USER:$USER Gemfile Gemfile.lock app.rb config.ru ./
COPY --chown=$USER:$USER app ./app
COPY --chown=$USER:$USER config ./config
COPY --chown=$USER:$USER public ./public
COPY --from=frontend-builder --chown=$USER:$USER /app/frontend/dist ./frontend/dist

CMD ["bundle", "exec", "falcon", "host", "./config/falcon.rb"]
