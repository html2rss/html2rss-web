![html2rss logo](https://github.com/html2rss/html2rss/raw/master/support/logo.png)

# html2rss-web [![](https://images.microbadger.com/badges/version/gilcreator/html2rss-web.svg)](https://hub.docker.com/r/gilcreator/html2rss-web)![mergify-status](https://img.shields.io/endpoint.svg?url=https://gh.mergify.io/badges/html2rss/html2rss-web&style=flat) [![](http://img.shields.io/liberapay/goal/gildesmarais.svg?logo=liberapa)](https://liberapay.com/gildesmarais/donate)

This is a small web application to deliver RSS feeds
built by [`html2rss`](https://github.com/html2rss/html2rss) via HTTP.

Features:

- serves your own feeds: set up your _feed configs_ in a YAML file. See [`html2rss`' README](https://github.com/html2rss/html2rss/blob/master/README.md#usage-with-a-yaml-config-file) for documentation.
- comes with all [`html2rss-configs`](https://github.com/html2rss/html2rss-configs) included.
- handles caching and HTTP Cache-Headers.

This web application is distributed in a [rolling release](https://en.wikipedia.org/wiki/Rolling_release)
fashion from the `master` branch.

💓 Depending on this application? [Feel free to donate](https://liberapay.com/gildesmarais/donate)! Thank you!

## Using the included `html2rss-configs`

Build the URL like this:

The _feed config_ you'd like to use:  
`lib/html2rss/configs/domainname.tld/whatever.yml`  
`‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌^^^^^^^^^^^^^^^^^^^^^^^^^^^`

The corresponding URL:  
`http://localhost:3000/domainname.tld/whatever.rss`  
`‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

👉 [See file list of all `html2rss-configs`.](https://github.com/html2rss/html2rss-configs/tree/master/lib/html2rss/configs)

## Deployment with Docker

Install Docker CE and `docker run -d -p 3000:3000 gilcreator/html2rss-web`.

To use your private _feed configs_, mount a `feed.yml` into the `/app/config/` folder.

```sh
docker run -d --name html2rss-web \
  --mount type=bind,source="/path/to/your/config/folder,target=/app/config" \
  -p 3000:3000 \
  gilcreator/html2rss-web
```

### Automatic updating

#### using containrrr/watchtower

The docker image [containrrr/watchtower](https://containrrr.dev/watchtower/) automatically pulls running docker images and checks for updates. If an update is available, it will start the updated image with the same configuration as the running one.

To start html2rss-web and let watchtower monitor it, save this as `start` script:

```sh
#!/bin/sh

docker run -d --name html2rss-web \
  --mount type=bind,source="/path/to/your/config/folder,target=/app/config" \
  -p 3000:3000 \
  gilcreator/html2rss-web

docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  --interval=7200 \
  html2rss-web
```

Watchtower will pull in a 2h interval to check if there's a new image and cleanup (remove the stopped previous image).

#### via cronjob

A primitive way to automatically update your Docker instance is to set up this
script as a cronjob. This has the disadvantage that it restarts the container without first checking whether an update is available or not.

```bash
#!/bin/bash
set -e
docker pull -q gilcreator/html2rss-web
(docker stop html2rss-web && docker rm html2rss-web) || :
docker run -d --name html2rss-web --restart=always -p 3000:3000  \
  --mount type=bind,source="/home/deploy/html2rss-web/config,target=/app/config" \
  gilcreator/html2rss-web
```

The cronjob for updating every 30 minutes could look like this:

```
*/30 *  * * * /home/deploy/html2rss-web/update > /dev/null 2>&1
```

## Heroku one-click deployment

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/html2rss/html2rss-web)

Since this repository receives updates frequently, you'd need to update your
instance yourself.

## Run it locally

1. Install Ruby `>= 2.6`.
2. `gem install bundler foreman`
3. `bundle`
4. `foreman start`

_html2rss-web_ now listens on port **5**000 for requests.

## Build and run with docker locally

This approach allows you to play around without installing Ruby on your machine.
All you need to do is install and run the Docker daemon.

```sh
# Build image from Dockerfile and name/tag it as html2rss-web:
docker build -t html2rss-web -f Dockerfile .

# Run the image and name it html2rss-web-dev:
docker run \
  --detach \
  --mount type=bind,source=$(pwd)/config,target=/app/config \
  --name html2rss-web-dev \
  html2rss-web

# Open a interactive TTY with the shell `sh`:
docker exec -ti html2rss-web-dev sh

# Stop and cleanup container
docker stop html2rss-web-dev
docker rm html2rss-web-dev

# Remove the image
docker rmi html2rss-web
```

## _Feed configs_ runtime health checks

Websites often change their markup. To get notified when one of _your own_ configs
break, use the `/health_check.txt` endpoint.

It will respond with `success` if your feeds are generatable.
Otherwise it will not print `success`, but states the broken config names.

## Supported ENV variables

| Name                           | Description            |
| ------------------------------ | ---------------------- |
| `PORT`                         | default: 3000          |
| `RACK_ENV`                     | default: 'development' |
| `RACK_TIMEOUT_SERVICE_TIMEOUT` | default: 15            |
| `WEB_CONCURRENCY`              | default: 2             |
| `WEB_MAX_THREADS`              | default: 5             |
