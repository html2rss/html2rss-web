# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Auto source functionality for generating RSS feeds from any website
    module AutoSource
      module_function

      def enabled?
        ENV['AUTO_SOURCE_ENABLED'] == 'true'
      end

      def authenticate(request)
        auth = request.env['HTTP_AUTHORIZATION']
        return false unless auth&.start_with?('Basic ')

        credentials = Base64.decode64(auth[6..]).split(':')
        username, password = credentials

        username == ENV['AUTO_SOURCE_USERNAME'] &&
          password == ENV['AUTO_SOURCE_PASSWORD']
      end

      def allowed_origin?(request)
        origin = request.env['HTTP_HOST'] || request.env['HTTP_X_FORWARDED_HOST']
        allowed_origins = (ENV['AUTO_SOURCE_ALLOWED_ORIGINS'] || '').split(',').map(&:strip)

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
