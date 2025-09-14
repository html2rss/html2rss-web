# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Auto source functionality for generating RSS feeds from any website
    module AutoSource
      module_function

      def enabled?
        # Enable by default in development, require explicit setting in production
        rack_env = ENV['RACK_ENV']
        auto_source_enabled = ENV['AUTO_SOURCE_ENABLED']

        if rack_env == 'development'
          auto_source_enabled != 'false'
        else
          auto_source_enabled == 'true'
        end
      end

      def authenticate(request)
        auth = request.env['HTTP_AUTHORIZATION']
        return false unless auth&.start_with?('Basic ')

        credentials = Base64.decode64(auth[6..]).split(':')
        username, password = credentials

        # Use default credentials in development if not set
        expected_username = ENV['AUTO_SOURCE_USERNAME'] || (ENV['RACK_ENV'] == 'development' ? 'admin' : nil)
        expected_password = ENV['AUTO_SOURCE_PASSWORD'] || (ENV['RACK_ENV'] == 'development' ? 'password' : nil)

        return false unless expected_username && expected_password

        username == expected_username && password == expected_password
      end

      def allowed_origin?(request)
        origin = request.env['HTTP_HOST'] || request.env['HTTP_X_FORWARDED_HOST']

        # In development, allow localhost origins by default
        if ENV['RACK_ENV'] == 'development'
          allowed_origins = (ENV['AUTO_SOURCE_ALLOWED_ORIGINS'] || 'localhost:3000,localhost:3001,127.0.0.1:3000,127.0.0.1:3001').split(',').map(&:strip)
        else
          allowed_origins = (ENV['AUTO_SOURCE_ALLOWED_ORIGINS'] || '').split(',').map(&:strip)
        end

        allowed_origins.empty? || allowed_origins.include?(origin)
      end

      def allowed_url?(url)
        allowed_urls = (ENV['AUTO_SOURCE_ALLOWED_URLS'] || '').split(',').map(&:strip)
        return true if allowed_urls.empty?

        allowed_urls.any? do |pattern|
          if pattern.include?('*')
            # Convert wildcard pattern to regex
            regex_pattern = pattern.gsub('*', '.*')
            url.match?(Regexp.new(regex_pattern))
          else
            url.include?(pattern)
          end
        end
      end

      def generate_feed(encoded_url, strategy = 'ssrf_filter')
        decoded_url = Base64.decode64(encoded_url)

        config = {
          stylesheets: [{ href: '/rss.xsl', type: 'text/xsl' }],
          strategy: strategy.to_sym,
          channel: { url: decoded_url },
          auto_source: {}
        }

        Html2rss.feed(config)
      end

      def error_feed(message)
        <<~RSS
          <?xml version="1.0" encoding="UTF-8"?>
          <rss version="2.0">
            <channel>
              <title>Error</title>
              <description>Failed to generate auto-source feed: #{message}</description>
              <item>
                <title>Error</title>
                <description>#{message}</description>
              </item>
            </channel>
          </rss>
        RSS
      end

      def access_denied_feed(url)
        <<~RSS
          <?xml version="1.0" encoding="UTF-8"?>
          <rss version="2.0">
            <channel>
              <title>Access Denied</title>
              <description>This URL is not allowed for public auto source generation.</description>
              <item>
                <title>Access Denied</title>
                <description>URL '#{url}' is not in the allowed list for public auto source.</description>
              </item>
            </channel>
          </rss>
        RSS
      end
    end
  end
end
