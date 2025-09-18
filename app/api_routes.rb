# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # API routes for the html2rss-web application
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
        params = router.params
        rss_content = Feeds.generate_feed(feed_name, params)
        set_rss_headers(router)
        rss_content.to_s
      rescue StandardError => error
        router.response.status = 500
        router.response['Content-Type'] = 'application/xml'
        Feeds.error_feed(error.message)
      end

      def set_rss_headers(router)
        router.response['Content-Type'] = 'application/xml'
        router.response['Cache-Control'] = 'public, max-age=3600'
        router.response['X-Content-Type-Options'] = 'nosniff'
        router.response['X-XSS-Protection'] = '1; mode=block'
      end
    end
  end
end
