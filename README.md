![html2rss logo](https://github.com/gildesmarais/html2rss/raw/master/support/logo.png)

# html2rss-web [![Build Status](https://travis-ci.com/gildesmarais/html2rss-web.svg?branch=master)](https://travis-ci.com/gildesmarais/html2rss-web) [![](https://images.microbadger.com/badges/version/gilcreator/html2rss-web.svg)](https://hub.docker.com/gilcreator/html2rss-web)

This is a tiny web application to expose HTTP endpoints which deliver RSS feeds
built by the [html2rss gem](https://github.com/gildesmarais/html2rss).

Out of the box you'll get all configs from [html2rss-configs](https://github.com/gildesmarais/html2rss-configs).
You can - optionally - create your own configs and keep them private.

## Quickstart

1. Install Docker CE.
2. `docker run -d -p 3000:3000 gilcreator/html2rss-web`

Now, how to use the configs from [html2rss-configs](https://github.com/gildesmarais/html2rss-configs)? The URL is build like this:

The config you want to use:  
[`lib/html2rss/configs/github.com/nuxt.js_releases.yml`](https://github.com/gildesmarais/html2rss-configs/blob/master/lib/html2rss/configs/github.com/nuxt.js_releases.yml)
`                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

The corresponding URL:  
`http://localhost:3000/github.com/nuxt.js_releases.rss`
`                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^`

## Use your own configs

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
  foobar: 'baz'
feeds:
  myfeed:
    channel: …
    selectors: …
```

The URL of your RSS feed is: http://localhost:3000/myfeed.rss

You can get an overview of all feeds of *your* feeds at http://localhost:3000/.

### Runtime health checks of your feeds

Websites often change their markup. To get notified when one of your configs
break, monitor the `/health_check.txt` endpoint.

It will respond with `success` if all feeds can be generated without any error.
Otherwise it will not print success, but the information which config is broken.

## Usage without Docker

E.g. in development mode or with your own deployment method.

Fork this project, add your `config/feeds.yml` and deploy it.

For development, you can use `foreman` to start the application:
`bundle exec foreman start`

`html2rss-web` now listens on port 3000 for your requests.
