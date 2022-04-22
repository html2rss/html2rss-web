# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

dev = ENV.fetch('RACK_ENV', nil) == 'development'

if dev
  require 'logger'
  logger = Logger.new($stdout)
end

require 'rack/unreloader'
Unreloader = Rack::Unreloader.new(subclasses: %w[Roda Html2rss],
                                  logger:,
                                  reload: dev) do
  App::App
end

Unreloader.require('app.rb') { 'App' }
Unreloader.require('./app/health_check.rb')
Unreloader.require('./app/html2rss_facade.rb')
Unreloader.require('./app/http_cache.rb')
Unreloader.require('./app/local_config.rb')
Unreloader.require('./app/request_path.rb')

run(dev ? Unreloader : App::App.freeze.app)
