# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'rack-timeout'
require_relative 'app/web/boot/development_reloader'

if ENV.key?('SENTRY_DSN')
  Bundler.require(:sentry)
  require 'sentry-ruby'

  Sentry.init do |config|
    config.dsn = ENV.fetch('SENTRY_DSN')

    config.traces_sample_rate = 1.0
    config.profiles_sample_rate = 1.0
  end

  use Sentry::Rack::CaptureExceptions
end

dev = ENV.fetch('RACK_ENV', nil) == 'development'

if dev
  require_relative 'app'

  run Html2rss::Web::Boot::DevelopmentReloader.new(
    loader: Html2rss::Web::Boot.loader,
    app_provider: -> { Html2rss::Web::App.app }
  )
else
  use Rack::Timeout

  require_relative 'app'
  Html2rss::Web::Boot.eager_load!

  run(Html2rss::Web::App.freeze.app)
end
