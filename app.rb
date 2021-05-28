# frozen_string_literal: true

# TODO: add csp stuff
require 'rack/cache'
require 'rack-timeout'

require_relative './app/health_check'
require_relative './app/html2rss_facade'

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

  plugin :error_handler do |error|
    case error
    when Html2rss::Config::ParamsMissing
      @page_title = 'Parameters missing'
      response.status = 422
    when Html2rss::AttributePostProcessors::UnknownPostProcessorName,
         Html2rss::ItemExtractors::UnknownExtractorName,
         Html2rss::Config::ChannelMissing
      @page_title = 'Invalid feed config'
      response.status = 422
    when LocalConfig::NotFound,
         Html2rss::Configs::ConfigNotFound
      @page_title = 'Feed config not found'
      response.status = 404
    else
      warn "#{e.class}: #{e.message}\n"
      warn e.backtrace
      @page_title = 'Internal Server Error'
    end

    @error = error
    view 'error'
  end

  plugin :public
  plugin :render, escape: true, layout: 'layout'
  plugin :typecast_params

  route do |r|
    r.root do
      view 'index'
    end

    r.public

    r.get 'health_check.txt' do |_|
      HttpCache.expires_now

      HealthCheck.run
    rescue StandardError => e
      "Error #{e.class} with message: #{e.message}"
    end

    # Route for feeds from the local feeds.yml
    r.get String do |_config_name_with_ext|
      path = RequestPath.new(request)

      Html2rssFacade.from_local_config(path.full_config_name, typecast_params) do |config|
        response['Content-Type'] = 'text/xml'

        HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
      end
    end

    # Route for feeds from html2rss-configs
    r.get String, String do |_folder_name, _config_name_with_ext|
      path = RequestPath.new(request)

      Html2rssFacade.from_config_name(path.full_config_name, typecast_params) do |config|
        response['Content-Type'] = 'text/xml'

        HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
      end
    end
  end
end
