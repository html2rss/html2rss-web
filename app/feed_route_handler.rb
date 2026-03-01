# frozen_string_literal: true

require_relative 'http_cache'

module Html2rss
  module Web
    ##
    # Handles legacy/static feed route rendering concerns.
    module FeedRouteHandler
      class << self
        # @param context [Html2rss::Web::AppContext::Context]
        # @param router [Roda::RodaRequest]
        # @param feed_name [String]
        # @return [String]
        def call(context:, router:, feed_name:)
          content, ttl_seconds = fetch_feed_payload(context, router, feed_name)
          emit_success(context, feed_name, router.params['strategy'])
          configure_response(router, ttl_seconds)
          content
        rescue StandardError => error
          emit_failure(context, feed_name, error)
          raise
        end

        private

        # @param context [Html2rss::Web::AppContext::Context]
        # @param feed_name [String]
        # @param strategy [String, nil]
        # @return [void]
        def emit_success(context, feed_name, strategy)
          context.observability.emit(
            event_name: 'feed.render',
            outcome: 'success',
            details: { feed_name: feed_name, strategy: strategy },
            level: :info
          )
        end

        # @param context [Html2rss::Web::AppContext::Context]
        # @param feed_name [String]
        # @param error [StandardError]
        # @return [void]
        def emit_failure(context, feed_name, error)
          context.observability.emit(
            event_name: 'feed.render',
            outcome: 'failure',
            details: { feed_name: feed_name, error_class: error.class.name, error_message: error.message },
            level: :warn
          )
        end

        # @param context [Html2rss::Web::AppContext::Context]
        # @param router [Roda::RodaRequest]
        # @param feed_name [String]
        # @return [Array<(String, Integer)>]
        def fetch_feed_payload(context, router, feed_name)
          context.feed_request_handler.call(
            feed_name: feed_name,
            params: router.params,
            async_refresh: context.flags.async_feed_refresh_enabled?
          )
        end

        # @param router [Roda::RodaRequest]
        # @param ttl_seconds [Integer]
        # @return [void]
        def configure_response(router, ttl_seconds)
          router.response['Content-Type'] = 'application/xml'
          HttpCache.expires(router.response, ttl_seconds, cache_control: 'public')
        end
      end
    end
  end
end
