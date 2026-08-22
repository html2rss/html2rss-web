# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Resolves, renders, and emits feed responses for both token and legacy routes.
      #
      # +feed.render+ Observability for completed Service outcomes is emitted only from
      # {Contracts::RenderResult} fields. +emit_failure+ covers exceptions outside that path.
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
            return emit_success(target_kind:, identifier:, resolved_source:, result:) if result.status == :ok
            return emit_empty(target_kind:, identifier:, resolved_source:, result:) if result.status == :empty

            emit_error(target_kind:, identifier:, resolved_source:, result:)
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
            emit_render_failure(
              target_kind:, identifier:, resolved_source:,
              reason: empty_reason_for(result),
              **result.diagnostics.to_h
            )
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def emit_error(target_kind:, identifier:, resolved_source:, result:) # rubocop:disable Metrics/MethodLength
            SentryOps.emit_failure_telemetry(
              decision: result.decision,
              diagnostics: result.diagnostics,
              event_name: 'feed.render',
              details: render_details(
                resolved_source, identifier, target_kind,
                error_code: result.decision.code,
                error_message: result.error_message || result.client_message,
                **result.diagnostics.to_h
              ),
              level: :warn,
              context: { url: resolved_source.url, strategy: resolved_source.strategy }
            )
          end

          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param extras [Hash{Symbol=>Object}]
          # @return [void]
          def emit_render_failure(target_kind:, identifier:, resolved_source:, **extras)
            Observability.emit(
              event_name: 'feed.render',
              outcome: 'failure',
              details: render_details(resolved_source, identifier, target_kind, **extras),
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
          # @return [String]
          def empty_reason_for(result)
            reason = result.empty_reason
            raise ArgumentError, 'empty RenderResult requires empty_reason' if reason.to_s.empty?

            reason
          end

          # Emits for exceptions outside a completed RenderResult emit path.
          #
          # @param target_kind [Symbol]
          # @param identifier [String]
          # @param error [StandardError]
          # @return [void]
          def emit_failure(target_kind:, identifier:, error:)
            decision = ErrorClassifier.classify(error)
            diagnostics = ErrorClassifier::Diagnostics.from_error(error)
            SentryOps.emit_failure_telemetry(
              decision:, diagnostics:, event_name: 'feed.render',
              details: exception_failure_details(target_kind:, identifier:, error:, decision:, diagnostics:),
              level: :warn
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
              error_message: error.message,
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
