# frozen_string_literal: true

require_relative '../errors/exceptions'
require_relative '../rendering/feed_response_format'
require_relative '../domain/feed_contracts'
require_relative '../feeds/json_renderer'
require_relative '../feeds/request_parser'
require_relative '../feeds/resolver'
require_relative '../feeds/rss_renderer'
require_relative '../feeds/service'
require_relative 'feed_response'

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

            emit_result(context, feed_name, resolved_source.generator_input[:strategy], result)
            FeedResponse.call(response: router.response, representation: feed_request.representation, result: result)
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
          # @param feed_name [String]
          # @param strategy [String, nil]
          # @param result [Html2rss::Web::FeedContracts::RenderResult]
          # @return [void]
          def emit_result(context, feed_name, strategy, result)
            return emit_success(context, feed_name, strategy) unless result.status == :error

            emit_failure(
              context,
              feed_name,
              InternalServerError.new(result.error_message || result.message || HttpError::DEFAULT_MESSAGE)
            )
          end
        end
      end
    end
  end
end
