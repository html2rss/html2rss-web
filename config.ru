# frozen_string_literal: true

require './app'
require 'rack/cache'
require 'rack-timeout'

use Rack::Timeout, service_timeout: ENV.fetch('RACK_TIMEOUT_SERVICE_TIMEOUT', 15)

use Rack::Cache,
    metastore: 'file:./tmp/rack-cache-meta',
    entitystore: 'file:./tmp/rack-cache-body',
    verbose: (ENV['RACK_ENV'] == 'development')

run App
