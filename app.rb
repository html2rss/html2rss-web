# frozen_string_literal: true

require 'roda'
require 'rack/cache'
require_relative 'roda/roda_plugins/basic_auth'

module Html2rss
  module Web
    ##
    # This app uses html2rss and serves the feeds via HTTP.
    #
    # It is built with [Roda](https://roda.jeremyevans.net/).
    class App < Roda
      CONTENT_TYPE_RSS = 'application/xml'

      def self.development? = ENV['RACK_ENV'] == 'development'

      opts[:check_dynamic_arity] = false
      opts[:check_arity] = :warn

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
        csp.font_src :self, 'data:'
        csp.form_action :self
        csp.base_uri :none
        csp.frame_ancestors :self
        csp.frame_src :self
        csp.block_all_mixed_content
      end

      plugin :default_headers,
             'Content-Type' => 'text/html',
             'X-Content-Type-Options' => 'nosniff',
             'X-XSS-Protection' => '1; mode=block'

      plugin :exception_page
      plugin :error_handler do |error|
        next exception_page(error) if development?

        handle_error(error)
      end

      plugin :hash_branch_view_subdir
      plugin :public
      plugin :content_for
      plugin :render, escape: true, layout: 'layout'
      plugin :typecast_params
      plugin :basic_auth

      Dir['routes/**/*.rb'].each { |f| require_relative f }

      route do |r|
        r.public
        r.hash_branches('')

        r.root { view 'index' }

        r.get 'health_check.txt' do
          handle_health_check
        end

        r.on String, String do |folder_name, config_name_with_ext|
          handle_html2rss_configs(request, folder_name, config_name_with_ext)
        end

        r.on String do |config_name_with_ext|
          handle_local_config_feeds(request, config_name_with_ext)
        end
      end

      Dir['helpers/*.rb'].each { |f| require_relative f }
    end
  end
end
