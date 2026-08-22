ARG RUBY_BASE_IMAGE=ruby:4.0.1-alpine3.23@sha256:7d1c4a23da9b3539fdeb5f970950a8fe044a707219e546f12152b84bbd5755d1
ARG NODE_BASE_IMAGE=node:22-alpine@sha256:8094c002d08262dba12645a3b4a15cd6cd627d30bc782f53229a2ec13ee22a00

# Stage 1: Frontend Build
FROM ${NODE_BASE_IMAGE} AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package.json frontend/pnpm-lock.yaml frontend/pnpm-workspace.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm run build

# Stage 2: Ruby Build
FROM ${RUBY_BASE_IMAGE} AS builder

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
  'libxml2-dev>=2' \
  'libxslt-dev>=1' \
  && gem install bundler:$(tail -1 Gemfile.lock | tr -d ' ') \
  && bundle config set --local without 'development test' \
  && bundle install --retry=5 --jobs=$(nproc) \
  && bundle binstubs bundler html2rss \
  && bundle clean --force \
  && rm -rf /usr/local/bundle/cache \
    /usr/local/bundle/bundler/gems/*/.git \
    /usr/local/bundle/cache/bundler/git

# Stage 3: Runtime
FROM ${RUBY_BASE_IMAGE}

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
  && mkdir -p /app/tmp/rack-cache-body \
  && mkdir -p /app/tmp/rack-cache-meta \
  && mkdir -p /app/data/registries \
  && chown "$USER":"$USER" -R /app

WORKDIR /app

USER 991

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --chown=$USER:$USER bin/docker-healthcheck ./bin/docker-healthcheck
COPY --chown=$USER:$USER Gemfile Gemfile.lock app.rb config.ru ./
COPY --chown=$USER:$USER app ./app
COPY --chown=$USER:$USER config ./config
COPY --chown=$USER:$USER app/registries/seed ./app/registries/seed
COPY --chown=$USER:$USER public ./public
COPY --from=frontend-builder --chown=$USER:$USER /app/frontend/dist ./frontend/dist

CMD ["bundle", "exec", "puma", "-C", "./config/puma.rb"]
