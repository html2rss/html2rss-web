# frozen_string_literal: true

module Html2rss
  module Web
    module ErrorClassifier
      ##
      # Immutable HTTP decision for a classified error.
      Decision = Data.define(
        :status, :code, :message, :kind, :cacheable, :retryable, :next_action, :retry_action
      ) do
        # Builds an uncacheable-by-default decision from positional identity and keyword meta.
        #
        # @param status [Integer]
        # @param code [String]
        # @param message [String]
        # @param attrs [Hash{Symbol=>Object}] +cacheable+ (default +false+), kind, retryable, next_action, retry_action
        # @return [Decision]
        def self.of(status, code, message, attrs = {}) = new(status:, code:, message:, cacheable: false, **attrs)

        # Maps <500 classified decisions to their empty RenderResult reason.
        #
        # @return [String]
        def empty_reason
          case code
          when ErrorClassifier::BLOCKED_SURFACE_CODE then 'blocked_surface'
          when 'FORBIDDEN' then 'forbidden'
          when 'BAD_REQUEST' then 'invalid_input'
          else 'content_extraction_empty'
          end
        end
      end
    end
  end
end
