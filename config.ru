require './app'
require 'rack/cache'

use Rack::Cache,
    metastore: 'file:./tmp/rack-cache-meta',
    entitystore: 'file:./tmp/rack-cache-body',
    verbose: true

run App
