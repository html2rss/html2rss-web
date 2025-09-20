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
app_requires = Dir['app/**/*.rb']
route_requires = Dir['routes/**/*.rb']
helper_requires = Dir['helpers/**/*.rb']

if dev
  require 'logger'
  logger = Logger.new($stdout)

  require 'rack/unreloader'
  Unreloader = Rack::Unreloader.new(subclasses: %w[Roda Html2rss],
                                    logger:,
                                    reload: dev) do
                                      Html2rss::Web::App
                                    end
  Unreloader.require('app.rb') { 'Html2rss::Web::App' }

  app_requires.each { |f| Unreloader.require(f) }
  route_requires.each { |f| Unreloader.require(f) }
  helper_requires.each { |f| Unreloader.require(f) }

  run Unreloader
else
  use Rack::Timeout

  require_relative 'app'
  app_requires.each { |f| require_relative f }
  route_requires.each { |f| require_relative f }
  helper_requires.each { |f| require_relative f }

  run(Html2rss::Web::App.freeze.app)
end
