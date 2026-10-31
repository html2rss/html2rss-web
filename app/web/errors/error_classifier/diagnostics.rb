# frozen_string_literal: true

module Html2rss
  module Web
    module ErrorClassifier
      ##
      # Gem strategy attempts plus expanded transport telemetry for feed Observability / headers.
      Diagnostics = Data.define(
        :strategy_attempts, :request_id, :strategy_used, :render_ms, :error_category, :timeout_phase,
        :surface_category
      ) do
        # Every member is optional; +strategy_attempts+ defaults to an empty list, the rest to +nil+.
        #
        # @param attrs [Hash{Symbol=>Object}]
        def initialize(attrs = {}) = super(**members.to_h { [it, nil] }, strategy_attempts: [].freeze, **attrs)

        class << self
          # @return [Diagnostics]
          def empty = self::EMPTY

          # Digs strategy attempts and surface_category from the exception cause chain.
          # Prefer +timeout_phase+ from transport_meta; else from +RequestTimedOut+ in the chain.
          # Carried {DecidedError} diagnostics win when non-empty.
          #
          # @param error [Exception, nil]
          # @return [Diagnostics]
          def from_error(error)
            return error.diagnostics if error.is_a?(DecidedError) && error.diagnostics != empty

            found = new(**chain_fields(ErrorClassifier.error_chain(error)))
            found == empty ? empty : found
          end

          # Expands attempt hashes into transport fields (single dig algorithm).
          #
          # @param attempts [Array<Hash>, nil]
          # @return [Diagnostics]
          def from_attempts(attempts)
            list = Array(attempts)
            list.empty? ? empty : new(strategy_attempts: list, **transport_fields(list))
          end

          private

          # @param chain [Array<Exception>]
          # @return [Hash{Symbol=>Object}]
          def chain_fields(chain)
            gem_errors = chain.grep(::Html2rss::Error)
            attempts = gem_errors.map { Array(it.attempts) }.find(&:any?) || []
            fields = transport_fields(attempts, fallback_meta: gem_errors.filter_map(&:transport_meta).find(&:any?))
            fields.merge(
              strategy_attempts: attempts,
              timeout_phase: fields[:timeout_phase] || chain_attr(chain, ::Html2rss::RequestService::RequestTimedOut,
                                                                  :timeout_phase),
              surface_category: chain_attr(chain, ::Html2rss::NoFeedItemsExtracted, :surface_category)
            )
          end

          # @param chain [Array<Exception>]
          # @param klass [Class]
          # @param attr [Symbol]
          # @return [Object, nil]
          def chain_attr(chain, klass, attr) = chain.grep(klass).first&.public_send(attr)

          # @param attempts [Array<Hash>]
          # @param fallback_meta [Hash, nil]
          # @return [Hash{Symbol=>Object}]
          def transport_fields(attempts, fallback_meta: nil)
            meta = attempts.filter_map { it[:transport_meta] || it['transport_meta'] }.last || fallback_meta
            self::TRANSPORT_KEYS.to_h { |key| [key, meta && (meta[key] || meta[key.to_s])] }
          end
        end

        # Sparse hash for Observability emit (omits blank fields).
        #
        # @return [Hash{Symbol=>Object}]
        def to_h = super.reject { |_, val| val.nil? || val == [] }
      end

      Diagnostics::TRANSPORT_KEYS = %i[request_id strategy_used render_ms error_category timeout_phase].freeze
      Diagnostics::EMPTY = Diagnostics.new.freeze
    end
  end
end
