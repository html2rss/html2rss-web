# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'rack-timeout'

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

require 'rack/attack'
require_relative 'config/rack_attack'
use Rack::Attack

dev = ENV.fetch('RACK_ENV', nil) == 'development'

if dev
  require 'logger'
  require 'rack/unreloader'

  logger = Logger.new($stdout)
  logger.level = Logger::INFO

  # Simple Unreloader configuration following official docs
  Unreloader = Rack::Unreloader.new(
    subclasses: %w[Roda Html2rss],
    logger: logger,
    reload: true
  ) do
    Html2rss::Web::App
  end

  # Load main app file
  Unreloader.require('app.rb') { 'Html2rss::Web::App' }

  # Load all directories - Unreloader handles the rest
  Unreloader.require('helpers')
  Unreloader.require('app')

  run Unreloader
else
  use Rack::Timeout

  # Production: load everything upfront for better performance
  require_relative 'app'
  Dir['app/**/*.rb'].each { |f| require_relative f }
  Dir['helpers/**/*.rb'].each { |f| require_relative f }

  run(Html2rss::Web::App.freeze.app)
end
