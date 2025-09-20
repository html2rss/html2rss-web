# frozen_string_literal: true

require_relative '../app/local_config'
require_relative '../app/base_route_handler'

module Html2rss
  module Web
    ##
    # API routes for the html2rss-web application
    # Now uses BaseRouteHandler to eliminate repetitive patterns
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
        context = BaseRouteHandler.create_context(router)

        BaseRouteHandler.with_error_handling(context) do |ctx|
          rss_content = Feeds.generate_feed(feed_name, ctx.params)

          config = LocalConfig.find(feed_name)
          ttl = config.dig(:channel, :ttl) || 3600

          BaseRouteHandler.rss_response(ctx, rss_content, ttl: ttl)
        end
      end
    end
  end
end
