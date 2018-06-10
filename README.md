# html2rss-web

A minimal Sinatra based web application to demo the use of the
[html2rss  gem](https://github.com/gildesmarais/html2rss).

This application exposes HTTP-endpoints of the configured feeds.

# Usage

Fork this project, add your `config.yml` and deploy it.
For local development, you can use `foreman` to start the application:
`bundle exec foreman start`


Now you can yequest the feeds at `/*feed_name*.rss`, e.g. `/nuxt-releases.rss`.
