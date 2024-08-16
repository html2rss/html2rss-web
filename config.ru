# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

dev = ENV.fetch('RACK_ENV', nil) == 'development'

requires = Dir['app/**/*.rb']

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
  requires.each { |f| Unreloader.require(f) }

  run Unreloader
else
  requires.each { |f| require_relative f }
  run(Html2rss::Web::App.freeze.app)
end
