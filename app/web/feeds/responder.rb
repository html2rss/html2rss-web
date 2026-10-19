# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      # Resolves, renders, and emits feed responses for both token and legacy routes.
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
            feed_request = Contracts::Request.from_rack_request(request, target_kind:, identifier:)
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
            Observability.emit(
              event_name: 'feed.render',
              outcome: result.status == :ok ? 'success' : 'failure',
              details: render_details(resolved_source, identifier, target_kind, **status_details(result)),
              level: result.status == :ok ? :info : :warn
            )
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [Hash{Symbol=>Object}]
          def status_details(result)
            case result.status
            in :ok then feed_status_details(result)
            in :empty then { reason: empty_reason_for(result), **result.diagnostics.to_h }
            in :error then { error_code: result.decision.code, **result.diagnostics.to_h }
            end
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
            decision = ErrorClassifier.classify(error)
            diagnostics = ErrorClassifier::Diagnostics.from_error(error)
            Observability.emit(
              event_name: 'feed.render', outcome: 'failure', level: :warn,
              details: exception_failure_details(target_kind:, identifier:, error:, decision:, diagnostics:)
            )
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param error [StandardError]
          # @param decision [Html2rss::Web::ErrorClassifier::Decision]
          # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
          # @return [Hash{Symbol=>Object}]
          def exception_failure_details(target_kind:, identifier:, error:, decision:, diagnostics:)
            {
              error_class: error.class.name,
              error_code: decision.code,
              **diagnostics.to_h
            }.tap do |details|
              details[:feed_name] = identifier if target_kind == :static
            end
          end
        end
      end
    end
  end
end
