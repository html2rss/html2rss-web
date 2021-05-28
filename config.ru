# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'roda'

dev = ENV['RACK_ENV'] == 'development'

if dev
  require 'logger'
  logger = Logger.new($stdout)
end

require 'rack/unreloader'
Unreloader = Rack::Unreloader.new(subclasses: %w[Roda Html2rss], logger: logger, reload: dev) { App }

Unreloader.require('app/app.rb') { 'App' }
Unreloader.require('./app/health_check.rb')
Unreloader.require('./app/html2rss_facade.rb')
Unreloader.require('./app/http_cache.rb')
Unreloader.require('./app/local_config.rb')
Unreloader.require('./app/request_path.rb')

run(dev ? Unreloader : App.freeze.app)
