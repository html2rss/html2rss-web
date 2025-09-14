# frozen_string_literal: true

require 'roda'
require 'rack/cache'

require 'html2rss'
require_relative 'app/ssrf_filter_strategy'
require_relative 'app/auto_source'
require_relative 'app/feeds'

module Html2rss
  module Web
    ##
    # This app uses html2rss and serves the feeds via HTTP.
    #
    # It is built with [Roda](https://roda.jeremyevans.net/).
    class App < Roda
      CONTENT_TYPE_RSS = 'application/xml'

      Html2rss::RequestService.register_strategy(:ssrf_filter, SsrfFilterStrategy)
      Html2rss::RequestService.default_strategy_name = :ssrf_filter
      Html2rss::RequestService.unregister_strategy(:faraday)

      def self.development? = ENV['RACK_ENV'] == 'development'

      opts[:check_dynamic_arity] = false
      opts[:check_arity] = :warn

      use Rack::Cache,
          metastore: 'file:./tmp/rack-cache-meta',
          entitystore: 'file:./tmp/rack-cache-body',
          verbose: false

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
        next exception_page(error) if ENV['RACK_ENV'] == 'development'

        response.status = 500
        'Internal Server Error'
      end

      plugin :public
      plugin :hash_branches
      plugin :render, engine: 'erb', views: 'views'

      @show_backtrace = !ENV['CI'].to_s.empty? || (ENV['RACK_ENV'] == 'development')

      # API routes
      hash_branch 'api' do |r|
        r.on 'feeds.json' do
          response['Content-Type'] = 'application/json'
          response['Cache-Control'] = 'public, max-age=300'
          JSON.generate(Feeds.list_feeds)
        end

        r.on String do |feed_name|
          handle_feed_generation(r, feed_name)
        end
      end

      # Auto source routes
      hash_branch 'auto_source' do |r|
        return auto_source_disabled_response unless AutoSource.enabled?

        r.on String do |encoded_url|
          handle_auto_source_feed(r, encoded_url)
        end

        r.get { auto_source_instructions_response }
      end

      # Health check route
      hash_branch 'health_check.txt' do |r|
        handle_health_check(r)
      end

      route do |r|
        r.public
        r.hash_branches
        handle_static_files(r)
      end

      private

      # API route helpers
      def handle_feed_generation(router, feed_name)
        params = router.params
        rss_content = Feeds.generate_feed(feed_name, params)
        set_rss_headers
        rss_content.to_s
      rescue StandardError => error
        response.status = 500
        response['Content-Type'] = CONTENT_TYPE_RSS
        Feeds.error_feed(error.message)
      end

      def set_rss_headers
        response['Content-Type'] = CONTENT_TYPE_RSS
        response['Cache-Control'] = 'public, max-age=3600'
        response['X-Content-Type-Options'] = 'nosniff'
        response['X-XSS-Protection'] = '1; mode=block'
      end

      # Auto source route helpers
      def auto_source_disabled_response
        response.status = 400
        'The auto source feature is disabled.'
      end

      def auto_source_instructions_response
        response.status = 200
        response['Content-Type'] = 'text/html'
        render(:auto_source_instructions)
      end

      def handle_auto_source_feed(router, encoded_url)
        return unauthorized_response unless AutoSource.authenticate(router)
        return forbidden_origin_response unless AutoSource.allowed_origin?(router)

        process_auto_source_request(router, encoded_url)
      rescue StandardError => error
        handle_auto_source_error(error)
      end

      def process_auto_source_request(router, encoded_url)
        decoded_url = Base64.decode64(encoded_url)
        return access_denied_response(decoded_url) unless AutoSource.allowed_url?(decoded_url)

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed(encoded_url, strategy)
        set_auto_source_headers
        rss_content.to_s
      end

      def handle_auto_source_error(error)
        response.status = 500
        response['Content-Type'] = CONTENT_TYPE_RSS
        AutoSource.error_feed(error.message)
      end

      def unauthorized_response
        response.status = 401
        response['WWW-Authenticate'] = 'Basic realm="Auto Source"'
        'Unauthorized'
      end

      def forbidden_origin_response
        response.status = 403
        'Origin is not allowed.'
      end

      def access_denied_response(url)
        response.status = 403
        response['Content-Type'] = CONTENT_TYPE_RSS
        AutoSource.access_denied_feed(url)
      end

      def set_auto_source_headers
        response['Content-Type'] = CONTENT_TYPE_RSS
        response['Cache-Control'] = 'private, must-revalidate, no-cache, no-store, max-age=0'
        response['X-Content-Type-Options'] = 'nosniff'
        response['X-XSS-Protection'] = '1; mode=block'
      end

      # Health check route helpers
      def handle_health_check(router)
        auth = router.env['HTTP_AUTHORIZATION']
        if auth&.start_with?('Basic ')
          handle_health_check_auth(auth)
        else
          health_check_unauthorized
        end
      end

      def handle_health_check_auth(auth)
        credentials = Base64.decode64(auth[6..]).split(':')
        username, password = credentials

        if health_check_authenticated?(username, password)
          response['Content-Type'] = 'text/plain'
          HealthCheck.run
        else
          health_check_unauthorized
        end
      end

      def health_check_authenticated?(username, password)
        expected_username, expected_password = health_check_credentials
        expected_username && expected_password &&
          username == expected_username && password == expected_password
      end

      def health_check_credentials
        username = ENV.fetch('HEALTH_CHECK_USERNAME', nil)
        password = ENV.fetch('HEALTH_CHECK_PASSWORD', nil)

        # In development, use default credentials if not set
        if username.nil? && ENV.fetch('RACK_ENV', nil) == 'development'
          username = 'admin'
          password = 'password'
        end

        [username, password]
      end

      def health_check_unauthorized
        response.status = 401
        response['WWW-Authenticate'] = 'Basic realm="Health Check"'
        'Unauthorized'
      end

      # Static file helpers
      def handle_static_files(router)
        router.on do
          if router.path_info == '/'
            serve_root_path
          elsif File.exist?("public#{router.path_info}")
            router.public
          else
            serve_astro_files(router)
          end
        end
      end

      def serve_root_path
        index_path = 'public/frontend/index.html'
        if File.exist?(index_path)
          response['Content-Type'] = 'text/html'
          File.read(index_path)
        else
          not_found_response
        end
      end

      def serve_astro_files(router)
        astro_path = "public/frontend#{router.path_info}"
        if File.exist?("#{astro_path}/index.html")
          serve_astro_file("#{astro_path}/index.html")
        elsif File.exist?(astro_path) && File.file?(astro_path)
          serve_astro_file(astro_path)
        else
          not_found_response
        end
      end

      def serve_astro_file(file_path)
        response['Content-Type'] = 'text/html'
        File.read(file_path)
      end

      def not_found_response
        response.status = 404
        'Not Found'
      end
    end
  end
end
