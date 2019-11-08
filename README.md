![html2rss logo](https://github.com/gildesmarais/html2rss/raw/master/support/logo.png)

# html2rss-web [![Build Status](https://travis-ci.com/gildesmarais/html2rss-web.svg?branch=master)](https://travis-ci.com/gildesmarais/html2rss-web) [![](https://images.microbadger.com/badges/version/gilcreator/html2rss-web.svg)](https://hub.docker.com/r/gilcreator/html2rss-web)![mergify-status](https://img.shields.io/endpoint.svg?url=https://gh.mergify.io/badges/gildesmarais/html2rss-web&style=flat)

This is a small web application to deliver RSS feeds
built by [`html2rss`](https://github.com/gildesmarais/html2rss) via HTTP.

Features:

- serves your own feeds: set up your _feed configs_ in a YAML file. See [`html2rss`' README](https://github.com/gildesmarais/html2rss/blob/master/README.md#usage-with-a-yaml-config-file) for documentation.
- comes with all [`html2rss-configs`](https://github.com/gildesmarais/html2rss-configs) included.
- handles caching and HTTP Cache-Headers.

This web application is distributed in a [rolling release](https://en.wikipedia.org/wiki/Rolling_release)
fashion from the `master` branch.

## Using the included `html2rss-configs`

Build the URL like this:

The _feed config_ you'd like to use:  
`lib/html2rss/configs/domainname.tld/whatever.yml`  
`‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌^^^^^^^^^^^^^^^^^^^^^^^^^^^`

The corresponding URL:  
`http://localhost:3000/domainname.tld/whatever.rss`  
`‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ‌ ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

👉 [See file list of all `html2rss-configs`.](https://github.com/gildesmarais/html2rss-configs/tree/master/lib/html2rss/configs)

## Deployment with Docker

Install Docker CE and `docker run -d -p 3000:3000 gilcreator/html2rss-web`.

To use your private _feed configs_, mount a `feed.yml` into the `/app/config/` folder.

```
docker run -d --name html2rss-web \
  --mount type=bind,source="/path/to/your/config/folder,target=/app/config" \
  -p 3000:3000 \
  gilcreator/html2rss-web
```

### Automatic updating

A primitive way to automatically update your Docker instance is to set up this
script as a cronjob:

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

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/gildesmarais/html2rss-web)

Since this repository receives updates frequently, you'd need to update your
instance yourself.

## Run it locally

1. Install Ruby `>= 2.6`.
2. `gem install bundler foreman`
3. `bundle`
4. `foreman start`

_html2rss-web_ now listens on port **5**000 for requests.

## _Feed configs_ runtime health checks

Websites often change their markup. To get notified when one of _your own_ configs
break, use the `/health_check.txt` endpoint.

It will respond with `success` if your feeds are generatable.
Otherwise it will not print `success`, but states the broken config names.
