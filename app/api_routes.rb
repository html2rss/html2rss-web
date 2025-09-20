# frozen_string_literal: true

require_relative 'local_config'

module Html2rss
  module Web
    ##
    # API routes for the html2rss-web application
    module ApiRoutes
      module_function

      ##
      # List available request strategies
      # @return [Hash] hash with strategies array
      def list_available_strategies
        strategies = Html2rss::RequestService.strategy_names.map do |name|
          {
            name: name.to_s,
            display_name: name.to_s.split('_').map(&:capitalize).join(' ')
          }
        end

        { strategies: strategies }
      end

      ##
      # Handle feed generation request
      # @param router [Roda::Request] request router
      # @param feed_name [String] name of the feed to generate
      # @return [String] RSS content
      def handle_feed_generation(router, feed_name)
        params = router.params
        rss_content = Feeds.generate_feed(feed_name, params)

        config = LocalConfig.find(feed_name)
        ttl = config.dig(:channel, :ttl) || 3600

        rss_headers(router, ttl: ttl)
        rss_content.to_s
      rescue StandardError => error
        router.response.status = 500
        router.response['Content-Type'] = 'application/xml'
        Feeds.error_feed(error.message)
      end

      ##
      # Set RSS response headers
      # @param router [Roda::Request] request router
      # @param ttl [Integer] time to live in seconds
      def rss_headers(router, ttl: 3600)
        router.response['Content-Type'] = 'application/xml'
        router.response['Cache-Control'] = "public, max-age=#{ttl}"
      end
    end
  end
end
