# Stage 1: Frontend Build
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --only=production
COPY frontend/ ./
RUN npm run build

# Stage 2: Ruby Build
FROM ruby:3.4.5-alpine3.21 AS builder

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
  'openssl>=3' \
  'libxml2-dev>=2' \
  'libxslt-dev>=1' \
  && gem install bundler:$(tail -1 Gemfile.lock | tr -d ' ') \
  && bundle config set --local without 'development test' \
  && bundle install --retry=5 --jobs=$(nproc) \
  && bundle binstubs bundler html2rss

# Stage 3: Runtime
FROM ruby:3.4.5-alpine3.21

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

ENV PORT=3000 \
  RACK_ENV=production \
  RUBY_YJIT_ENABLE=1

EXPOSE $PORT

HEALTHCHECK --interval=30m --timeout=60s --start-period=5s \
  CMD curl -f http://${HEALTH_CHECK_USERNAME}:${HEALTH_CHECK_PASSWORD}@localhost:${PORT}/health_check.txt || exit 1

ARG USER=html2rss
ARG UID=991
ARG GID=991

RUN apk add --no-cache \
  'curl>=8' \
  'gcompat>=0' \
  'tzdata>=2024' \
  'libxml2>=2' \
  'libxslt>=1' \
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
  && chown "$USER":"$USER" -R /app

WORKDIR /app

USER html2rss

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --chown=$USER:$USER . /app
COPY --from=frontend-builder --chown=$USER:$USER /app/frontend/dist ./public/frontend

CMD ["bundle", "exec", "puma", "-C", "./config/puma.rb"]
