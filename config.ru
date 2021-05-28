# frozen_string_literal: true

require 'roda'

dev = ENV['RACK_ENV'] == 'development'

if dev
  require 'logger'
  logger = Logger.new($stdout)
end

require 'rack/unreloader'
Unreloader = Rack::Unreloader.new(subclasses: %w[Roda Html2rss], logger: logger, reload: dev) { App }

Unreloader.require('app/app.rb') { 'App' }
Unreloader.require('./app/local_config.rb')
Unreloader.require('./app/path.rb')
Unreloader.require('./app/health_check.rb')

run(dev ? Unreloader : App.freeze.app)
