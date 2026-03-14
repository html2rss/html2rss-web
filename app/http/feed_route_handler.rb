# frozen_string_literal: true

require_relative '../feed_response_format'
require_relative '../feeds/json_renderer'
require_relative '../feeds/request_parser'
require_relative '../feeds/resolver'
require_relative '../feeds/rss_renderer'
require_relative '../feeds/service'
require_relative '../http_cache'

module Html2rss
  module Web
    module Http
      ##
      # Renders static feed requests through the shared feed pipeline.
      module FeedRouteHandler
        class << self
          # @param context [Html2rss::Web::AppContext::Context]
          # @param router [Roda::RodaRequest]
          # @param feed_name [String]
          # @return [String]
          def call(context:, router:, feed_name:)
            feed_request = Feeds::RequestParser.call(request: router, target_kind: :static, identifier: feed_name)
            resolved_source = Feeds::Resolver.call(feed_request)
            result = Feeds::Service.call(resolved_source)

            raise InternalServerError, result.message if result.status == :error

            emit_success(context, feed_name, resolved_source.generator_input[:strategy])
            configure_response(router, result.ttl_seconds, feed_request.representation)
            render_result(result, feed_request.representation)
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

          # @param result [Html2rss::Web::Feeds::Result]
          # @param format [Symbol]
          # @return [String]
          def render_result(result, format)
            return Feeds::JsonRenderer.call(result) if format == Feeds::ResponseFormat::JSON_FEED

            Feeds::RssRenderer.call(result)
          end

          # @param router [Roda::RodaRequest]
          # @param ttl_seconds [Integer]
          # @param format [Symbol]
          # @return [void]
          def configure_response(router, ttl_seconds, format)
            router.response['Content-Type'] = FeedResponseFormat.content_type(format)
            HttpCache.expires(router.response, ttl_seconds, cache_control: 'public')
            HttpCache.vary(router.response, 'Accept')
          end
        end
      end
    end
  end
end
