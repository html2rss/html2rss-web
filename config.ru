# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'rack-timeout'
require 'rack/protection'
require 'rack/protection/path_traversal'

use Rack::Timeout
use Rack::Protection
use Rack::Protection::PathTraversal

requires = Dir['app/**/*.rb']

if ENV.fetch('RACK_ENV', nil) == 'development'
  require 'logger'
  require 'rack/unreloader'

  logger = Logger.new($stdout)

  Unreloader = Rack::Unreloader.new(subclasses: %w[Roda Html2rss],
                                    logger:,
                                    reload: true) do
                                      Html2rss::Web::App
                                    end
  Unreloader.require('app.rb') { 'Html2rss::Web::App' }

  requires.each { |f| Unreloader.require(f) }

  run Unreloader
else
  require_relative 'app'
  requires.each { |f| require_relative f }

  run(Html2rss::Web::App.freeze.app)
end
