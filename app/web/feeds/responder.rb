# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Resolves, renders, and writes feed responses for both token and legacy routes.
      module Responder
        class << self
          # @param request [Rack::Request]
          # @param target_kind [Symbol]
          # @param identifier [String]
          # @return [String] serialized feed body.
          def call(request:, target_kind:, identifier:)
            feed_request, resolved_source, result = resolve_request(request:, target_kind:, identifier:)
            body = Renderer.render(result, response: request.response, request: request)
            emit_response_result(target_kind:, identifier:, feed_request:, resolved_source:, result:)
            body
          rescue StandardError => error
            emit_failure(target_kind:, identifier:, error:)
            raise
          end

          private

          # @param request [Rack::Request]
          # @param target_kind [Symbol]
          # @param identifier [String]
          # @return [Array<(Html2rss::Web::Feeds::Contracts::Request, Html2rss::Web::Feeds::Contracts::ResolvedSource, Html2rss::Web::Feeds::Contracts::RenderResult)>]
          def resolve_request(request:, target_kind:, identifier:)
            feed_request = Request.call(request:, target_kind:, identifier:)
            resolved_source = SourceResolver.call(feed_request)
            result = Service.call(resolved_source)
            [feed_request, resolved_source, result]
          end

          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @param identifier [String]
          # @return [String]
          def normalized_identifier(feed_request, identifier)
            feed_request.feed_name || identifier
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_response_result(target_kind:, identifier:, feed_request:, resolved_source:, result:)
            emit_result(
              target_kind:,
              identifier: normalized_identifier(feed_request, identifier),
              resolved_source:,
              result:
            )
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_result(target_kind:, identifier:, resolved_source:, result:)
            return emit_success(target_kind:, identifier:, resolved_source:) if result.status == :ok
            return emit_empty(target_kind:, identifier:, resolved_source:, result:) if result.status == :empty

            emit_failure(
              target_kind:,
              identifier:,
              error: Html2rss::Web::InternalServerError.new(
                result.error_message || result.message || Html2rss::Web::HttpError::DEFAULT_MESSAGE
              )
            )
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @return [void]
          def emit_success(target_kind:, identifier:, resolved_source:)
            details = {
              url: resolved_source.generator_input.dig(:channel, :url)
            }
            strategy = resolved_source.generator_input[:strategy]
            details[:strategy] = strategy if strategy
            details[:feed_name] = identifier if target_kind == :static

            Observability.emit(event_name: 'feed.render', outcome: 'success', details:, level: :info)
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_empty(target_kind:, identifier:, resolved_source:, result:)
            details = {
              url: resolved_source.generator_input.dig(:channel, :url),
              reason: empty_reason_for(result)
            }
            strategy = resolved_source.generator_input[:strategy]
            details[:strategy] = strategy if strategy
            details[:feed_name] = identifier if target_kind == :static

            Observability.emit(event_name: 'feed.render', outcome: 'failure', details:, level: :warn)
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def empty_reason_for(result)
            return 'content_extraction_empty' if result.error_kind == :extraction_empty

            'feed_empty'
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param error [StandardError]
          # @return [void]
          def emit_failure(target_kind:, identifier:, error:)
            details = { error_class: error.class.name, error_message: error.message }
            details[:feed_name] = identifier if target_kind == :static

            Observability.emit(event_name: 'feed.render', outcome: 'failure', details:, level: :warn)
          end
        end
      end
    end
  end
end
