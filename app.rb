# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require 'rack-timeout'
require_relative './app/health_check'
require_relative './app/local_config'
require_relative './app/html2rss_facade'

module App
  ##
  # This app uses html2rss and serves the feeds via HTTP.
  #
  # It is built with [Roda](https://roda.jeremyevans.net/).
  class App < Roda
    opts[:check_dynamic_arity] = false
    opts[:check_arity] = :warn

    use Rack::Timeout

    use Rack::Cache,
        metastore: 'file:./tmp/rack-cache-meta',
        entitystore: 'file:./tmp/rack-cache-body',
        verbose: (ENV.fetch('RACK_ENV', nil) == 'development')

    plugin :content_security_policy do |csp|
      csp.default_src :none
      csp.style_src :self
      csp.script_src :self
      csp.connect_src :self
      csp.img_src :self
      csp.font_src :self
      csp.form_action :self
      csp.base_uri :none
      csp.frame_ancestors :none
      csp.block_all_mixed_content
    end

    plugin :default_headers,
           'Content-Type' => 'text/html',
           'X-Frame-Options' => 'deny',
           'X-Content-Type-Options' => 'nosniff',
           'X-XSS-Protection' => '1; mode=block'

    plugin :error_handler do |error|
      case error
      when Html2rss::Config::ParamsMissing,
           Roda::RodaPlugins::TypecastParams::Error
        @page_title = 'Parameters missing or invalid'
        response.status = 422
      when Html2rss::AttributePostProcessors::UnknownPostProcessorName,
           Html2rss::ItemExtractors::UnknownExtractorName,
           Html2rss::Config::ChannelMissing
        @page_title = 'Invalid feed config'
        response.status = 422
      when ::App::LocalConfig::NotFound,
           Html2rss::Configs::ConfigNotFound
        @page_title = 'Feed config not found'
        response.status = 404
      else
        @page_title = 'Internal Server Error'
        response.status = 500
      end

      @show_backtrace = ENV.fetch('RACK_ENV', nil) == 'development'
      @error = error
      view 'error'
    end

    plugin :public
    plugin :render, escape: true, layout: 'layout'
    plugin :typecast_params

    route do |r|
      path = RequestPath.new(request)

      r.root do
        view 'index'
      end

      r.public

      r.get 'health_check.txt' do |_|
        HttpCache.expires_now(response)

        HealthCheck.run
      end

      # Route for feeds from the local feeds.yml
      r.get String do |_config_name_with_ext|
        Html2rssFacade.from_local_config(path.full_config_name, typecast_params) do |config|
          response['Content-Type'] = 'text/xml'

          HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
        end
      end

      # Route for feeds from html2rss-configs
      r.get String, String do |_folder_name, _config_name_with_ext|
        Html2rssFacade.from_config(path.full_config_name, typecast_params) do |config|
          response['Content-Type'] = 'text/xml'

          HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
        end
      end
    end
  end
end
