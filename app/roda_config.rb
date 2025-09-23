# frozen_string_literal: true

require_relative 'ssrf_filter_strategy'

module Html2rss
  module Web
    ##
    # Roda configuration for html2rss-web
    # Handles Roda app setup, plugins, and middleware configuration
    module RodaConfig
      module_function

      ##
      # Configure Roda app with all necessary plugins and middleware
      # @param app [Class] The Roda app class to configure
      def configure(app)
        setup_html2rss_strategies
        configure_roda_options(app)
        setup_middleware(app)
        setup_security_plugins(app)
        setup_error_handling(app)
        setup_plugins(app)
      end

      def setup_html2rss_strategies
        Html2rss::RequestService.register_strategy(:ssrf_filter, SsrfFilterStrategy)
        Html2rss::RequestService.default_strategy_name = :ssrf_filter
        Html2rss::RequestService.unregister_strategy(:faraday)
      end

      def configure_roda_options(app)
        app.opts[:check_dynamic_arity] = false
        app.opts[:check_arity] = :warn
      end

      def setup_middleware(app)
        app.use Rack::Cache,
                metastore: 'file:./tmp/rack-cache-meta',
                entitystore: 'file:./tmp/rack-cache-body',
                verbose: false
      end

      def setup_security_plugins(app)
        app.plugin :content_security_policy do |csp|
          configure_csp(csp)
        end

        app.plugin :default_headers, default_security_headers
      end

      def configure_csp(csp)
        configure_csp_sources(csp)
        configure_csp_security(csp)
      end

      def configure_csp_sources(csp)
        csp.default_src :none
        csp.style_src :self, "'unsafe-inline'" # Allow inline styles for Starlight
        csp.script_src :self, "'unsafe-inline'" # Allow inline scripts for progressive enhancement
        csp.connect_src :self
        csp.img_src :self, 'data:', 'blob:'
        csp.font_src :self, 'data:'
        csp.form_action :self
        csp.base_uri :none
      end

      def configure_csp_security(csp)
        csp.frame_ancestors :self # Allow iframe embedding from same origin
        csp.frame_src :self # Allow iframes for RSS feeds
        csp.object_src :none # Prevent object/embed/applet
        csp.media_src :none # Prevent media sources
        csp.manifest_src :none # Prevent manifest
        csp.worker_src :none # Prevent workers
        csp.child_src :none # Prevent child contexts
        csp.block_all_mixed_content
        csp.upgrade_insecure_requests # Upgrade HTTP to HTTPS
      end

      def default_security_headers
        basic_security_headers.merge(advanced_security_headers)
      end

      def basic_security_headers
        {
          'Content-Type' => 'text/html',
          'X-Content-Type-Options' => 'nosniff',
          'X-XSS-Protection' => '1; mode=block',
          'X-Frame-Options' => 'SAMEORIGIN',
          'X-Permitted-Cross-Domain-Policies' => 'none',
          'Referrer-Policy' => 'strict-origin-when-cross-origin'
        }
      end

      def advanced_security_headers
        {
          'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()',
          'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains; preload',
          'Cross-Origin-Embedder-Policy' => 'require-corp',
          'Cross-Origin-Opener-Policy' => 'same-origin',
          'Cross-Origin-Resource-Policy' => 'same-origin',
          'X-DNS-Prefetch-Control' => 'off',
          'X-Download-Options' => 'noopen'
        }
      end

      def setup_error_handling(app)
        app.plugin :exception_page
        app.plugin :error_handler do |error|
          next exception_page(error) if app.development?

          response.status = 500
          response['Content-Type'] = 'application/xml'
          require_relative 'xml_builder'
          XmlBuilder.build_error_feed(message: error.message)
        end
      end

      def setup_plugins(app)
        app.plugin :public
        app.plugin :hash_branches
        app.plugin :json_parser # Handle JSON request bodies automatically
      end
    end
  end
end
