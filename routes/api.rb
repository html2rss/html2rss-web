# frozen_string_literal: true

require_relative '../app/local_config'
require_relative '../app/feeds'

module Html2rss
  module Web
    module ApiRoutes
      module_function

      def list_available_strategies
        strategies = Html2rss::RequestService.strategy_names.map do |name|
          {
            name: name.to_s,
            display_name: name.to_s.split('_').map(&:capitalize).join(' ')
          }
        end

        { strategies: strategies }
      end

      def handle_feed_generation(router, feed_name)
        rss_content = Feeds.generate_feed(feed_name, router.params)
        config = LocalConfig.find(feed_name)
        ttl = config.dig(:channel, :ttl) || 3600

        router.response['Content-Type'] = 'application/xml'
        router.response['Cache-Control'] = "public, max-age=#{ttl}"
        rss_content
      end
    end
  end
end
