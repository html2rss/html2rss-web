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
            emit_result(target_kind:, identifier: feed_request.feed_name || identifier, resolved_source:, result:)
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

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_result(target_kind:, identifier:, resolved_source:, result:)
            return emit_success(target_kind:, identifier:, resolved_source:, result:) if result.status == :ok
            return emit_empty(target_kind:, identifier:, resolved_source:, result:) if result.status == :empty

            message = result.error_message || result.message || Html2rss::Web::HttpError::DEFAULT_MESSAGE
            emit_failure(target_kind:, identifier:, error: Html2rss::Web::InternalServerError.new(message))
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_success(target_kind:, identifier:, resolved_source:, result:)
            Observability.emit(
              event_name: 'feed.render',
              outcome: 'success',
              details: render_details(resolved_source, identifier, target_kind, **feed_status_details(result)),
              level: :info
            )
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_empty(target_kind:, identifier:, resolved_source:, result:)
            Observability.emit(
              event_name: 'feed.render',
              outcome: 'failure',
              details: render_details(
                resolved_source, identifier, target_kind,
                reason: empty_reason_for(result),
                **strategy_attempts_details(result)
              ),
              level: :warn
            )
          end

          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param identifier [String]
          # @param target_kind [Symbol]
          # @param extras [Hash{Symbol=>Object}]
          # @return [Hash{Symbol=>Object}]
          def render_details(resolved_source, identifier, target_kind, **extras)
            details = { url: resolved_source.url, **extras }
            strategy = resolved_source.strategy
            details[:strategy] = strategy if strategy
            details[:feed_name] = identifier if target_kind == :static
            details
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [Hash{Symbol=>Object}]
          def feed_status_details(result)
            feed = result.payload&.feed
            return {} unless feed.respond_to?(:status)

            { scraper_status: feed.status.to_h }
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [Hash{Symbol=>Object}]
          def strategy_attempts_details(result)
            attempts = result.strategy_attempts
            attempts.nil? || attempts.empty? ? {} : { strategy_attempts: attempts }
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def empty_reason_for(result)
            reason = result.empty_reason
            raise ArgumentError, 'empty RenderResult requires empty_reason' if reason.to_s.empty?

            reason
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
