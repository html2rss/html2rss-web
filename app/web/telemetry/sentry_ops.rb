# frozen_string_literal: true

require 'html2rss/url'

module Html2rss
  module Web
    ##
    # Emits P0 operational failures to Sentry Issues.
    #
    # Distinct from {SentryLogs}, which mirrors structured stdout logs when
    # +SENTRY_ENABLE_LOGS=true+. This module consumes {ErrorClassifier::Decision}
    # codes only — it never re-classifies exceptions.
    module SentryOps
      OPERATIONAL_CODES = %w[
        SCRAPER_UNAVAILABLE
        GATEWAY_TIMEOUT
        INTERNAL_SERVER_ERROR
        SERVICE_UNAVAILABLE
      ].freeze
      SERVICE_NAME = 'html2rss-web'

      class << self
        # @param decision [Html2rss::Web::ErrorClassifier::Decision]
        # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
        # @param context [Hash{Symbol=>Object}]
        # @return [void]
        def emit_operational_failure(decision:, diagnostics:, context: {})
          return unless operational_code?(decision.code)
          return unless sentry_ready?

          capture_operational_failure(decision, diagnostics, context)
        rescue StandardError
          nil
        end

        private

        # @param decision [Html2rss::Web::ErrorClassifier::Decision]
        # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
        # @param context [Hash{Symbol=>Object}]
        # @return [void]
        def capture_operational_failure(decision, diagnostics, context)
          ::Sentry.capture_message(
            operational_message(decision, context),
            level: :error,
            tags: sentry_tags(decision, diagnostics, context),
            fingerprint: sentry_fingerprint(diagnostics, context),
            extra: sentry_extra(diagnostics, context)
          )
        end

        # @param code [String]
        # @return [Boolean]
        def operational_code?(code)
          OPERATIONAL_CODES.include?(code.to_s)
        end

        # @return [Boolean]
        def sentry_ready?
          RuntimeEnv.sentry_enabled? &&
            defined?(::Sentry) &&
            ::Sentry.respond_to?(:capture_message)
        end

        # @param decision [Html2rss::Web::ErrorClassifier::Decision]
        # @param context [Hash{Symbol=>Object}]
        # @return [String]
        def operational_message(decision, context)
          event = context[:event_name] || 'operational.failure'
          "#{event}: #{decision.code}"
        end

        # @param decision [Html2rss::Web::ErrorClassifier::Decision]
        # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
        # @param context [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def sentry_tags(decision, diagnostics, context)
          {
            error_code: decision.code,
            error_category: diagnostics.error_category,
            request_id: diagnostics.request_id,
            strategy: context[:strategy],
            strategy_used: diagnostics.strategy_used,
            host: hostname(context[:url]),
            render_ms: diagnostics.render_ms
          }.compact
        end

        # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
        # @param context [Hash{Symbol=>Object}]
        # @return [Array<String>]
        def sentry_fingerprint(diagnostics, context)
          [
            SERVICE_NAME,
            diagnostics.error_category || 'unknown',
            hostname(context[:url]) || 'unknown-host'
          ]
        end

        # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
        # @param context [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def sentry_extra(diagnostics, context)
          extras = {}
          extras[:event_name] = context[:event_name] if context[:event_name]
          extras[:request_id] = diagnostics.request_id if diagnostics.request_id
          extras
        end

        # @param url [Object]
        # @return [String, nil]
        def hostname(url)
          return if url.to_s.empty?

          Html2rss::Url.for_channel(url.to_s).host
        rescue StandardError
          nil
        end
      end
    end
  end
end
