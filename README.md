![html2rss logo](https://github.com/gildesmarais/html2rss/raw/master/support/logo.png)

# html2rss-web [![Build Status](https://travis-ci.com/gildesmarais/html2rss-web.svg?branch=master)](https://travis-ci.com/gildesmarais/html2rss-web) [![](https://images.microbadger.com/badges/version/gilcreator/html2rss-web.svg)](https://hub.docker.com/r/gilcreator/html2rss-web)

This is a compact web application to expose HTTP endpoints which deliver RSS feeds
built by the [html2rss gem](https://github.com/gildesmarais/html2rss).
It's distributed in a [_rolling release_](https://en.wikipedia.org/wiki/Rolling_release) fashion and thus the master branch is the one to use.

Out of the box the app comes with all configs from [html2rss-configs](https://github.com/gildesmarais/html2rss-configs) included. You can - optionally - create your own configs and keep them private.

## Use the baked-in `html2rss-configs`

To use the configs from [`html2rss-configs`](https://github.com/gildesmarais/html2rss-configs) build the URL like this:

The feed config you'd like to use:  
`lib/html2rss/configs/domainname.tld/whatever.yml`  
`                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

The corresponding URL:  
`http://localhost:3000/domainname.tld/whatever.rss`  
`                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

## Deployment

### Heroku one-click

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/gildesmarais/html2rss-web)

Since this repository receives updates frequently, you'd need to update your
instance yourself.

### with Docker

1. Install Docker CE.
2. `docker run -d -p 3000:3000 gilcreator/html2rss-web`

#### Use your own (private) configs

To use your private configs, mount a `feed.yml` into the `/app/config/` folder.

```
docker run -d --name html2rss-web \
  --mount type=bind,source="/path/to/your/config/folder,target=/app/config" \
  -p 3000:3000 \
  gilcreator/html2rss-web
```

When your `feeds.yml` looks like this:

```yml
headers:
  foobar: "baz"
feeds:
  myfeed:
    channel: …
    selectors: …
```

The URL of your RSS feed is: http://localhost:3000/myfeed.rss

#### Automatic updating

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

### None of the above

Fork this project, add a `config/feeds.yml` and deploy it.

Use `foreman` to start the application with automatic reloading provided by [rerun](https://github.com/alexch/rerun):

`bundle exec foreman start`

*html2rss-web* now listens on port **5**000 for requests.

## Runtime health checks of your private feeds

Websites often change their markup. To get notified when one of _your own_ configs
break, use the `/health_check.txt` endpoint.

It will respond with `success` if your feeds are generatable.
Otherwise it will not print `success`, but states the broken config names.
