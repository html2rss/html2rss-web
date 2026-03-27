# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'rack-timeout'
require_relative 'app/web/boot/development_reloader'
require_relative 'app'

use Sentry::Rack::CaptureExceptions if Html2rss::Web::Boot::Setup.sentry_enabled?

dev = ENV.fetch('RACK_ENV', nil) == 'development'

if dev
  run Html2rss::Web::Boot::DevelopmentReloader.new(
    loader: Html2rss::Web::Boot.loader,
    app_provider: -> { Html2rss::Web::App.app }
  )
else
  use Rack::Timeout

  Html2rss::Web::Boot.eager_load!

  run(Html2rss::Web::App.freeze.app)
end
