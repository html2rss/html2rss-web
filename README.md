# html2rss-web

A minimal Sinatra based web application to demo the use of the
[html2rss  gem](https://github.com/gildesmarais/html2rss).

This application exposes HTTP-endpoints of the configured feeds.

## Usage

### in development or with your own deployment method

Fork this project, add your `config/feeds.yml` and deploy it.

For development, you can use `foreman` to start the application:
`bundle exec foreman start`

`html2rss-web` now listens on port 3000 for your requests.

### with Docker

Find the official docker image [on Docker Hub](https://hub.docker.com/r/gilcreator/html2rss-web/).

```
docker run -d --name html2rss-web --mount type=bind,source="/path/to/your/config/folder,target=/app/config" -p 3000:3000 gilcreator/html2rss-web
```

Now you can request your feeds at `http://localhost:3000/*feed_name*.rss`, e.g. `http://localhost:3000/nuxt-releases.rss`.

## Runtime health checks of your feeds

Websites often change their markup. To get notified when one of your feeds breaks,
monitor the `/health_check.txt` endpoint.

It will return `success` if all feeds can be generated without any error.
Otherwise it will not state success, but print the information which feed is broken.
