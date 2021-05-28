# frozen_string_literal: true

# TODO: add csp stuff
require 'rack/cache'
require 'rack-timeout'

require_relative './health_check'
require_relative './html2rss_facade'

##
# This app uses html2rss and serves the feeds via HTTP.
#
# It is built with [Roda](https://roda.jeremyevans.net/).
class App < Roda
  use Rack::Timeout, service_timeout: ENV.fetch('RACK_TIMEOUT_SERVICE_TIMEOUT', 15)

  use Rack::Cache,
      metastore: 'file:./tmp/rack-cache-meta',
      entitystore: 'file:./tmp/rack-cache-body',
      verbose: (ENV['RACK_ENV'] == 'development')

  plugin :default_headers,
         'Content-Type' => 'text/html',
         'X-Frame-Options' => 'deny',
         'X-Content-Type-Options' => 'nosniff',
         'X-XSS-Protection' => '1; mode=block'

  plugin :public
  # TODO: plugin :error_handler
  plugin :typecast_params

  route do |r|
    r.root do
      # render default page layout with h2r info
      # TODO: add water.css to the default layout
      ENV['RACK_ENV']
    end

    r.public

    r.get 'health_check.txt' do |_|
      HttpCache.expires_now

      HealthCheck.run
    rescue StandardError => e
      "Error #{e.class} with message: #{e.message}"
    end

    # Route for feeds from the local feeds.yml
    r.get String do |config_name_with_ext|
      path = Path.new(config_name_with_ext)

      Html2rssFacade.from_local_config(path.name, typecast_params) do |config|
        response['Content-Type'] = 'text/xml'

        HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
      end
    end

    # Route for feeds from html2rss-configs
    r.get String, String do |folder_name, config_name_with_ext|
      path = Path.new(config_name_with_ext, folder_name)

      Html2rssFacade.from_config_name(path.name, typecast_params) do |config|
        response['Content-Type'] = 'text/xml'

        HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
      end
    end
  end
end
