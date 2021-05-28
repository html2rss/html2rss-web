# frozen_string_literal: true

# TODO: add csp stuff
require 'html2rss'
require 'html2rss/configs'
require 'yaml'
require 'rack/cache'
require 'rack-timeout'
require 'time'

require_relative './health_check'

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

  # TODO: plugin :assets
  plugin :public
  # TODO: plugin :error_handler
  plugin :typecast_params

  def html2rss_config(feed_config, typecast_params)
    feed_config_to_config(feed_config, typecast_params)
  end

  ##
  # @return [Html2rss::Config]
  # @raise [Roda::RodaPlugins::TypecastParams::Error]
  def feed_config_to_config(feed_config, typecast_params, global_config: LocalConfig.global)
    dynamic_params = Html2rss::Config.required_params_for_feed_config(feed_config)
                                     .map { |name| [name, typecast_params.str!(name)] }
                                     .to_h

    Html2rss::Config.new(feed_config, global_config, dynamic_params)
  end

  def expires(seconds, cache_control: nil)
    response['Expires'] = (Time.now + seconds).httpdate

    response['Cache-Control'] = if cache_control
                                  "max-age=#{seconds},#{cache_control}"
                                else
                                  "max-age=#{seconds}"
                                end
  end

  route do |r|
    r.root do
      # render default page layout with h2r info
      # TODO: add water.css to the default layout
      ENV['RACK_ENV']
    end

    r.public

    r.get 'health_check.txt' do |_|
      response['Content-Type'] = 'text/plain'
      response['Expires'] = '0'
      response['Cache-Control'] = 'private,max-age=0,no-cache,no-store,must-revalidate'

      HealthCheck.check
    rescue StandardError => e
      "error: #{e},\n#{e.message}"
    end

    r.get String do |config_name_with_ext|
      path = Path.new(config_name_with_ext)
      feed_config = LocalConfig.find path.name

      response['Content-Type'] = 'text/xml'

      config = html2rss_config(feed_config, typecast_params)
      expires(config.ttl * 60, cache_control: 'public')
      Html2rss.feed(config).to_s
    end

    r.get String, String do |folder_name, config_name_with_ext|
      path = Path.new(config_name_with_ext, folder_name)
      feed_config = Html2rss::Configs.find_by_name(path.name)

      response['Content-Type'] = 'text/xml'

      config = html2rss_config(feed_config, typecast_params)
      expires(config.ttl * 60, cache_control: 'public')
      Html2rss.feed(config).to_s
    end
  end
end
