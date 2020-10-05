FROM ruby:2.7.2-alpine3.11

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

EXPOSE 3000

ENV PORT=3000
ENV RACK_ENV=production

HEALTHCHECK --interval=5m --timeout=3s --start-period=5s \
  CMD curl -f http://localhost:3000/health_check.txt || exit 1

RUN apk add --no-cache \
  'git=~2' \
  'make=~4' \
  'gcc=~9' \
  'libc-dev=~0' \
  'tzdata>=2019b'

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
RUN gem install foreman:'< 1' bundler:'~> 1.0' \
    && bundle config --global frozen 1 \
    && bundle install --binstubs --retry=5 --jobs=7 --without development test

COPY --chown=html2rss:html2rss . .

CMD ["foreman", "start"]
