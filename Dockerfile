FROM ruby:3.3.0-alpine3.18

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

EXPOSE 3000

ENV PORT=3000
ENV RACK_ENV=production
ENV PATH="/app/bin:${PATH}"

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

HEALTHCHECK --interval=30m --timeout=60s --start-period=5s \
  CMD curl -f http://${HEALTH_CHECK_USERNAME}:${HEALTH_CHECK_PASSWORD}@localhost:3000/health_check.txt || exit 1

RUN apk add --no-cache --verbose \
  'curl>=8.5.0' \
  'gcc>=12' \
  'git=~2' \
  'libc-dev=~0' \
  'make=~4' \
  'openssl>=3.1.4' \
  'tzdata>=2023c-r1'

ARG USER=html2rss
ARG UID=991
ARG GID=991

RUN mkdir /app \
  && addgroup --gid "$GID" "$USER" \
  && adduser \
  --disabled-password \
  --gecos "" \
  --home "/app" \
  --ingroup "$USER" \
  --no-create-home \
  --uid "$UID" \
  "$USER" \
  && chown "$USER":"$USER" -R /app

WORKDIR /app

USER html2rss

COPY --chown=html2rss:html2rss Gemfile Gemfile.lock ./
# hadolint ignore=SC2046
RUN gem install bundler:$(tail -1 Gemfile.lock | tr -d ' ') \
  && bundle config set --local without 'development test' \
  && bundle install --retry=5 --jobs=$(nproc) \
  && bundle binstubs bundler html2rss

COPY --chown=html2rss:html2rss . .

CMD ["bundle", "exec", "puma -C config/puma.rb"]
