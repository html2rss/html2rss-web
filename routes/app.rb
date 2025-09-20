# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    ##
    # Main application routes for html2rss-web
    # Handles all route definitions and routing logic
    module AppRoutes
      def self.load_routes(app)
        load_api_routes(app)
        load_feed_routes(app)
        load_auto_source_routes(app)
        load_health_check_routes(app)
      end

      def self.load_api_routes(app)
        app.hash_branch 'api' do |r|
          r.response['Content-Type'] = 'application/json'
          load_api_endpoints(r)
        end
      end

      def self.load_api_endpoints(router)
        load_feeds_endpoint(router)
        load_strategies_endpoint(router)
        load_feed_generation_endpoint(router)
      end

      def self.load_feeds_endpoint(router)
        router.on 'feeds.json' do
          router.response['Cache-Control'] = 'public, max-age=300'
          JSON.generate(Feeds.list_feeds)
        end
      end

      def self.load_strategies_endpoint(router)
        router.on 'strategies.json' do
          router.response['Cache-Control'] = 'public, max-age=3600'
          JSON.generate(ApiRoutes.list_available_strategies)
        end
      end

      def self.load_feed_generation_endpoint(router)
        router.on String do |feed_name|
          ApiRoutes.handle_feed_generation(router, feed_name)
        end
      end

      def self.load_feed_routes(app)
        app.hash_branch 'feeds' do |r|
          r.on String do |feed_id|
            AutoSourceRoutes.handle_stable_feed(r, feed_id)
          end
        end
      end

      def self.load_auto_source_routes(app)
        app.hash_branch 'auto_source' do |r|
          AutoSourceRoutes.handle_auto_source_routes(r)
        end
      end

      def self.load_health_check_routes(app)
        app.hash_branch 'health_check.txt' do |r|
          HealthCheckRoutes.handle_health_check_routes(r)
        end
      end
    end
  end
end
