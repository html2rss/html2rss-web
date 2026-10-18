# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # One +feed.render+ sample after a subscribed response is committed, or when that response raises.
      module RenderOutcome
        class << self
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def record(result)
            result.cache_hit ? write('hit', 'none') : write_status(result)
            nil
          end

          # @param decision [Html2rss::Web::ErrorClassifier::Decision]
          # @return [void]
          def record_failure(decision)
            write('failure', Telemetry::Outcome.reason_for(decision))
            nil
          end

          private

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def write_status(result)
            case result.status
            when :ok then write('success', 'none')
            when :empty then write('empty', Telemetry::Outcome.empty_reason_for(result.empty_reason))
            when :error then write('failure', Telemetry::Outcome.reason_for(result.decision))
            end
            nil
          end

          # @param result [String]
          # @param reason [String]
          # @return [void]
          def write(result, reason)
            Telemetry::Outcome.record(operation: 'feed.render', result:, reason:)
            nil
          end
        end
      end
    end
  end
end
