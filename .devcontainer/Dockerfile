FROM ruby:3.4.6-alpine3.21

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
    tzdata

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
