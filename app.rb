# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require 'rack-timeout' # TODO: move to config.ru

require_relative 'roda/roda_plugins/basic_auth'

module Html2rss
  module Web
    ##
    # This app uses html2rss and serves the feeds via HTTP.
    #
    # It is built with [Roda](https://roda.jeremyevans.net/).
    class App < Roda
      def self.development?
        ENV['RACK_ENV'] == 'development'
      end

      def development? = self.class.development?

      opts[:check_dynamic_arity] = false
      opts[:check_arity] = :warn

      use Rack::Timeout # TODO: move to config.ru

      use Rack::Cache,
          metastore: 'file:./tmp/rack-cache-meta',
          entitystore: 'file:./tmp/rack-cache-body',
          verbose: development?

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

      plugin :exception_page
      plugin :error_handler do |error|
        next exception_page(error) if development?

        handle_error(error)
      end

      plugin :public
      plugin :render, escape: true, layout: 'layout'
      plugin :typecast_params
      plugin :basic_auth


      route do |r|
        r.root { view 'index' }

        r.public

        r.get 'health_check.txt' do
          handle_health_check
        end

        r.on String, String do |folder_name, config_name_with_ext|
          handle_html2rss_configs(path.full_config_name, folder_name, config_name_with_ext)
        end

        r.on String do |config_name_with_ext|
          handle_local_config_feeds(path.full_config_name, config_name_with_ext)
        end
      end

      private

      def handle_error(error) # rubocop:disable Metrics/MethodLength
        case error
        when Html2rss::Config::ParamsMissing,
             Roda::RodaPlugins::TypecastParams::Error
          set_error_response('Parameters missing or invalid', 422)
        when Html2rss::AttributePostProcessors::UnknownPostProcessorName,
             Html2rss::ItemExtractors::UnknownExtractorName,
             Html2rss::Config::ChannelMissing
          set_error_response('Invalid feed config', 422)
        when LocalConfig::NotFound,
             Html2rss::Configs::ConfigNotFound
          set_error_response('Feed config not found', 404)
        else
          set_error_response('Internal Server Error', 500)
        end

        @show_backtrace = ENV.fetch('RACK_ENV', nil) == 'development'
        @error = error
        view 'error'
      end

      def set_error_response(page_title, status)
        @page_title = page_title
        response.status = status
      end

      def handle_health_check
        HttpCache.expires_now(response)

        with_basic_auth(realm: HealthCheck,
                        username: HealthCheck::Auth.username,
                        password: HealthCheck::Auth.password) do
          HealthCheck.run
        end
      end

      def handle_local_config_feeds(full_config_name, _config_name_with_ext)
        Html2rssFacade.from_local_config(full_config_name, typecast_params) do |config|
          response['Content-Type'] = 'text/xml'
          HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
        end
      end

      def handle_html2rss_configs(full_config_name, _folder_name, _config_name_with_ext)
        Html2rssFacade.from_config(full_config_name, typecast_params) do |config|
          response['Content-Type'] = 'text/xml'
          HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
        end
      end
    end
  end
end
