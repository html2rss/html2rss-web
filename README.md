![html2rss logo](https://github.com/html2rss/html2rss/raw/master/support/logo.png)

# html2rss-web

This web application scrapes websites to build and deliver RSS 2.0 feeds.

**Features:**

- [Create your custom feeds](#how-to-build-your-rss-feeds)!
- Comes with plenty of [included configs](https://github.com/html2rss/html2rss-configs) out of the box.
- Handles request caching.
- Sets caching-related HTTP headers.

The functionality of scraping websites and building the RSS feeds is provided by the Ruby gem [`html2rss`](https://github.com/html2rss/html2rss).

## Get started

This application should be used with Docker. It is designed to require as little maintenance as possible. See [Versioning and Releases](#versioning-and-releases) and [consider automatic updates](#docker-automatically-keep-the-html2rss-web-image-up-to-date).

### With Docker

```sh
docker run -p 3000:3000 gilcreator/html2rss-web
```

Then open <http://127.0.0.1:3000/> in your browser and click the example feed link.

This is the quickest way to get started. However, it's also the option with the least flexibility: it doesn't allow you to use custom feed configs and doesn't update automatically.

If you want more flexibility and automatic updates sound good to you, read on to get started _with docker compose_…

### With `docker compose`

Create a `docker-compose.yml` file and paste the following into it:

```yaml
services:
  html2rss-web:
    image: gilcreator/html2rss-web
    ports:
      - "3000:3000"
    volumes:
      - type: bind
        source: ./feeds.yml
        target: /app/config/feeds.yml
        read_only: true
    environment:
      - RACK_ENV=production
      - HEALTH_CHECK_USERNAME=health
      - HEALTH_CHECK_PASSWORD=please-set-YOUR-OWN-veeeeeery-l0ng-aNd-h4rd-to-gue55-Passw0rd!
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - "~/.docker/config.json:/config.json"
    command: --cleanup --interval 7200
```

Start it up with: `docker compose up`.

If you have not created your `feeds.yml` yet, download [this `feeds.yml` as a blueprint](https://raw.githubusercontent.com/html2rss/html2rss-web/master/config/feeds.yml) into the directory containing the `docker-compose.yml`.

## Docker: Automatically keep the html2rss-web image up-to-date

The [watchtower](https://containrrr.dev/watchtower/) service automatically pulls running Docker images and checks for updates. If an update is available, it will automatically start the updated image with the same configuration as the running one. Please read its manual.

The `docker-compose.yml` above contains a service description for watchtower.

## How to use the included configs

html2rss-web comes with many feed configs out of the box. [See the file list of all configs.](https://github.com/html2rss/html2rss-configs/tree/master/lib/html2rss/configs)

To use a config from there, build the URL like this:

|                          |                               |
| ------------------------ | ----------------------------- |
| `lib/html2rss/configs/`  | `domainname.tld/whatever.yml` |
| Would become this URL:   |                               |
| `http://localhost:3000/` | `domainname.tld/whatever.rss` |
|                          | `^^^^^^^^^^^^^^^^^^^^^^^^^^^` |

## How to build your RSS feeds

To build your own RSS feed, you need to create a _feed config_.\
That _feed config_ goes into the file `feeds.yml`.\
Check out the [`example` feed config](https://github.com/html2rss/html2rss-web/blob/master/config/feeds.yml#L9).

Please refer to [html2rss' README for a description of _the feed config and its options_](https://github.com/html2rss/html2rss#the-feed-config-and-its-options). html2rss-web is just a small web application that depends on html2rss.

## Versioning and releases

This web application is distributed in a [rolling release](https://en.wikipedia.org/wiki/Rolling_release) fashion from the `master` branch.

For the latest commit passing GitHub CI/CD on the master branch, an updated Docker image will be pushed to [Docker Hub: `gilcreator/html2rss-web`](https://hub.docker.com/r/gilcreator/html2rss-web).

GitHub's @dependabot is enabled for dependency updates and they are automatically merged to the `master` branch when the CI gives the green light.

If you use Docker, you should update to the latest image automatically by [setting up _watchtower_ as described](#get-started).

## Use in production

This app is published on Docker Hub and therefore easy to use with Docker.\
The above `docker-compose.yml` is a good starting point.

If you're going to host a public instance, _please, please, please_:

- Put the application behind a reverse proxy.
- Allow outside connections only via HTTPS.
- Have an auto-update strategy (e.g., watchtower).
- Monitor your `/health_check.txt` endpoint.
- [Let the world know and add your instance to the wiki](https://github.com/html2rss/html2rss-web/wiki/Instances) -- thank you!

### Supported ENV variables

| Name                           | Description                      |
| ------------------------------ | -------------------------------- |
| `PORT`                         | default: 3000                    |
| `RACK_ENV`                     | default: 'development'           |
| `RACK_TIMEOUT_SERVICE_TIMEOUT` | default: 15                      |
| `WEB_CONCURRENCY`              | default: 2                       |
| `WEB_MAX_THREADS`              | default: 5                       |
| `HEALTH_CHECK_USERNAME`        | default: auto-generated on start |
| `HEALTH_CHECK_PASSWORD`        | default: auto-generated on start |

### Runtime monitoring via `GET /health_check.txt`

It is recommended to set up monitoring of the `/health_check.txt` endpoint. With that, you can find out when one of _your own_ configs breaks. The endpoint uses HTTP Basic authentication.

First, set the username and password via these environment variables: `HEALTH_CHECK_USERNAME` and `HEALTH_CHECK_PASSWORD`. If these are not set, html2rss-web will generate a new random username and password on _each_ start.

An authenticated `GET /health_check.txt` request will respond with:

- If the feeds are generatable: `success`.
- Otherwise: the names of the broken configs.

To get notified when one of your configs breaks, set up monitoring of this endpoint.

[UptimeRobot's free plan](https://uptimerobot.com/) is sufficient for basic monitoring (every 5 minutes).\
Create a monitor of type _Keyword_ with this information and make it aware of your username and password:

![A screenshot showing the Keyword Monitor: a name, the instance's URL to /health_check.txt, and an interval.](docs/uptimerobot_monitor.jpg)

## Setup for development

Check out the git repository and…

### Using Docker

This approach allows you to experiment without installing Ruby on your machine.
All you need to do is install and run Docker.

```sh
# Build image from Dockerfile and name/tag it as html2rss-web:
docker build -t html2rss-web -f Dockerfile .

# Run the image and name it html2rss-web-dev:
docker run \
  --detach \
  --mount type=bind,source=$(pwd)/config,target=/app/config \
  --name html2rss-web-dev \
  html2rss-web

# Open an interactive TTY with the shell `sh`:
docker exec -ti html2rss-web-dev sh

# Stop and clean up the container
docker stop html2rss-web-dev
docker rm html2rss-web-dev

# Remove the image
docker rmi html2rss-web
```

### Using installed Ruby

If you're comfortable with installing Ruby directly on your machine, follow these instructions:

1. Install Ruby `>= 3.2`
2. `gem install bundler foreman`
3. `bundle`
4. `foreman start`

_html2rss-web_ now listens on port **5000** for requests.

## Contribute

Contributions are welcome!

Open a pull request with your changes,\
open an issue, or\
[join discussions on html2rss](https://github.com/orgs/html2rss/discussions).
