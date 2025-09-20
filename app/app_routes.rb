# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    ##
    # Main application routes for html2rss-web
    # Handles all route definitions and routing logic
    module AppRoutes
      module_function

      ##
      # Define all application routes
      # @param app [Class] The Roda app class
      def define_routes(app)
        define_api_routes(app)
        define_feed_routes(app)
        define_auto_source_routes(app)
        define_health_check_routes(app)
        define_main_route(app)
      end

      def define_api_routes(app)
        app.hash_branch 'api' do |r|
          r.response['Content-Type'] = 'application/json'

          r.on 'feeds.json' do
            r.response['Cache-Control'] = 'public, max-age=300'
            JSON.generate(Feeds.list_feeds)
          end

          r.on 'strategies.json' do
            r.response['Cache-Control'] = 'public, max-age=3600'
            JSON.generate(ApiRoutes.list_available_strategies)
          end

          r.on String do |feed_name|
            ApiRoutes.handle_feed_generation(r, feed_name)
          end
        end
      end

      def define_feed_routes(app)
        app.hash_branch 'feeds' do |r|
          r.on String do |feed_id|
            AutoSourceRoutes.handle_stable_feed(r, feed_id)
          end
        end
      end

      def define_auto_source_routes(app)
        app.hash_branch 'auto_source' do |r|
          handle_auto_source_routes(r)
        end
      end

      def define_health_check_routes(app)
        app.hash_branch 'health_check.txt' do |r|
          handle_health_check_routes(r)
        end
      end

      def define_main_route(app)
        app.route do |r|
          r.public
          r.hash_branches
          handle_static_files(r)
        end
      end
    end
  end
end
