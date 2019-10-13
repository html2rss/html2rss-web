![html2rss logo](https://github.com/gildesmarais/html2rss/raw/master/support/logo.png)

# html2rss-web [![Build Status](https://travis-ci.com/gildesmarais/html2rss-web.svg?branch=master)](https://travis-ci.com/gildesmarais/html2rss-web) [![](https://images.microbadger.com/badges/version/gilcreator/html2rss-web.svg)](https://hub.docker.com/r/gilcreator/html2rss-web)

This is a tiny web application to expose HTTP endpoints which deliver RSS feeds
built by the [html2rss gem](https://github.com/gildesmarais/html2rss).
This app is versioned as "rolling release" and thus latest master branch should be used.

Out of the box you'll get all configs from [html2rss-configs](https://github.com/gildesmarais/html2rss-configs).
You can - optionally - create your own configs and keep them private.

## Usage of `html2rss-configs` configs

To use the configs from [`html2rss-configs`](https://github.com/gildesmarais/html2rss-configs) build the URL like this:

The config you want to use:  
`lib/html2rss/configs/domainname.tld/whatever.yml`  
`                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

The corresponding URL:  
`http://localhost:3000/domainname.tld/whatever.rss`  
`                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

## Deployment

### Heroku one-click

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/gildesmarais/html2rss-web)

Since this repository receives updates quiet often, you'd need to update your
instance manually.

### with Docker

1. Install Docker CE.
2. `docker run -d -p 3000:3000 gilcreator/html2rss-web`

#### Use your own configs

To use your private configs, mount a `feed.xml` into the `/app/config/` folder.

```
docker run -d --name html2rss-web \
  --mount type=bind,source="/path/to/your/config/folder,target=/app/config" \
  -p 3000:3000 \
  gilcreator/html2rss-web
```

When your `feeds.xml` looks like this:

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
docker stop html2rss-web && docker rm html2rss-web || :
docker run -d --name html2rss-web --restart=always -p 3000:3000 \
  --mount type=bind,source="/home/deploy/html2rss-web/config,target=/app/config" \
  gilcreator/html2rss-web
```

For updates every 30 minutes your cronjob could look like this:

```
*/30 *  * * * /home/deploy/html2rss/update > /dev/null 2>&1
```

### None of the above

E.g. in development mode or with your own deployment method.

Fork this project, add your `config/feeds.yml` and deploy it.

For development, you can use `foreman` to start the application:
`bundle exec foreman start`

`html2rss-web` now listens on port **5**000 for your requests.

## Runtime health checks of your feeds

Websites often change their markup. To get notified when one of _your own_ configs
break, monitor the `/health_check.txt` endpoint.

It will respond with `success` if all feeds can be generated without any error.
Otherwise it will not print success, but the information which config is broken.
