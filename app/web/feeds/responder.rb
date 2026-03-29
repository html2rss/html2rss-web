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
            body = write_response(response: request.response, representation: feed_request.representation, result:)
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

          # @param response [Rack::Response]
          # @param representation [Symbol]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def write_response(response:, representation:, result:)
            response.status = result.status == :error ? 500 : 200
            response['Content-Type'] = FeedResponseFormat.content_type(representation)
            apply_cache_headers(response, result)
            ::Html2rss::Web::HttpCache.vary(response, 'Accept')
            render_result(result, representation)
          end

          # @param response [Rack::Response]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def apply_cache_headers(response, result)
            return ::Html2rss::Web::HttpCache.expires_now(response) if result.status == :error

            ::Html2rss::Web::HttpCache.expires(response, result.ttl_seconds, cache_control: 'public')
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param representation [Symbol]
          # @return [String]
          def render_result(result, representation)
            return JsonRenderer.call(result) if representation == FeedResponseFormat::JSON_FEED

            RssRenderer.call(result)
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_result(target_kind:, identifier:, resolved_source:, result:)
            return emit_success(target_kind:, identifier:, resolved_source:) unless result.status == :error

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
              strategy: resolved_source.generator_input[:strategy],
              url: resolved_source.generator_input.dig(:channel, :url)
            }
            details[:feed_name] = identifier if target_kind == :static

            Observability.emit(event_name: 'feed.render', outcome: 'success', details:, level: :info)
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
