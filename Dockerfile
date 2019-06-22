FROM ruby:2.6-alpine

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

EXPOSE 3000

ENV PORT=3000
ENV RACK_ENV=production

HEALTHCHECK --interval=5m --timeout=3s --start-period=5s \
  CMD curl -f http://localhost:3000/ || exit 1

RUN apk add --no-cache git libffi-dev make gcc libc-dev

RUN mkdir /app

ARG USER=html2rss
ARG UID=991
ARG GID=991

RUN addgroup --gid "$GID" "$USER" \
    && adduser \
    --disabled-password \
    --gecos "" \
    --home "/app" \
    --ingroup "$USER" \
    --no-create-home \
    --uid "$UID" \
    "$USER"

RUN chown html2rss:html2rss -R /app
WORKDIR /app

USER html2rss

COPY --chown=html2rss:html2rss Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1
RUN bundle install --binstubs --retry=5 --jobs=7 --without development test

COPY --chown=html2rss:html2rss . .

CMD bundle exec foreman start
