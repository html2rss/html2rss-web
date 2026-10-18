# frozen_string_literal: true

module Html2rss
  module Web
    module Telemetry
      ##
      # Closed product fact for a feed render, feed create, or unexpected fault.
      #
      # Unknown operation, result, and reason combinations cannot be built.
      # rubocop:disable-next Lint/ConstantDefinitionInBlock
      Outcome = Data.define(:operation, :result, :reason) do
        RENDER = 'feed.render'
        CREATE = 'feed.create'
        FAULT = 'request.fault'
        FAILURE_REASONS = %w[
          scraper_unavailable service_unavailable gateway_timeout blocked_surface forbidden internal
        ].freeze
        CODE_REASONS = {
          'SCRAPER_UNAVAILABLE' => 'scraper_unavailable',
          'SERVICE_UNAVAILABLE' => 'service_unavailable',
          'GATEWAY_TIMEOUT' => 'gateway_timeout',
          'BLOCKED_SURFACE' => 'blocked_surface',
          'FORBIDDEN' => 'forbidden',
          'EXTRACTION_EMPTY' => 'extraction_empty',
          'INTERNAL_SERVER_ERROR' => 'internal'
        }.freeze
        EMPTY_REASONS = {
          'feed_empty' => 'feed_empty',
          'content_extraction_empty' => 'extraction_empty',
          'extraction_empty' => 'extraction_empty'
        }.freeze
        ALLOWED = (
          [
            [RENDER, 'hit', 'none'],
            [RENDER, 'success', 'none'],
            [RENDER, 'empty', 'feed_empty'],
            [RENDER, 'empty', 'extraction_empty'],
            [CREATE, 'success', 'none'],
            [FAULT, 'failure', 'internal']
          ] + FAILURE_REASONS.map { |reason| [RENDER, 'failure', reason] } +
            (FAILURE_REASONS + ['extraction_empty']).map { |reason| [CREATE, 'failure', reason] }
        ).to_set(&:freeze).freeze

        class << self
          # Writes the counter and, when a span is recording, the same three attributes.
          # Construction failures propagate. Metric and span failures are ignored.
          #
          # @param operation [String]
          # @param result [String]
          # @param reason [String]
          # @return [Html2rss::Web::Telemetry::Outcome]
          def record(operation:, result:, reason:)
            outcome = new(operation:, result:, reason:)
            outcome.write
            outcome
          end

          # Maps a classifier code onto a closed reason. Unknown codes become +internal+.
          #
          # @param decision [Html2rss::Web::ErrorClassifier::Decision, nil]
          # @return [String]
          def reason_for(decision)
            CODE_REASONS.fetch(decision&.code.to_s, 'internal')
          end

          # Maps a render empty reason onto the closed empty label.
          #
          # @param empty_reason [String]
          # @return [String]
          def empty_reason_for(empty_reason)
            EMPTY_REASONS.fetch(empty_reason.to_s, 'extraction_empty')
          end
        end

        # @param operation [String]
        # @param result [String]
        # @param reason [String]
        # @return [void]
        def initialize(operation:, result:, reason:)
          operation = operation.to_s
          result = result.to_s
          reason = reason.to_s
          raise ArgumentError, 'unknown outcome' unless ALLOWED.include?([operation, result, reason])

          super
        end

        # Prometheus labels for this fact.
        #
        # @return [Hash{Symbol=>String}]
        def labels
          { operation:, result:, reason: }
        end

        # @return [void]
        def write
          Metrics.increment(labels)
          Tracing.annotate!(self)
          nil
        rescue StandardError
          nil
        end
      end
    end
  end
end
