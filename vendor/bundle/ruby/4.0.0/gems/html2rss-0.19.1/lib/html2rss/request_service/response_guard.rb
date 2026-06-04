# frozen_string_literal: true

module Html2rss
  class RequestService
    ##
    # Enforces response-size limits before parsing.
    class ResponseGuard
      ##
      # @param policy [Policy] request policy that defines byte ceilings
      def initialize(policy:)
        @policy = policy
        @streamed_bytes = 0
      end

      ##
      # Validates response headers and streamed byte count.
      #
      # @param total_bytes [Integer] cumulative byte count received so far
      # @param headers [Hash, nil] response headers if known
      # @return [void]
      # @raise [ResponseTooLarge] if the response exceeds configured limits
      def inspect_chunk!(total_bytes:, headers: nil)
        header_length = headers&.fetch('content-length', headers&.fetch('Content-Length', nil))
        raise_if_too_large!(header_length.to_i, policy.max_response_bytes) if header_length

        @streamed_bytes = total_bytes
        raise_if_too_large!(@streamed_bytes, policy.max_response_bytes)
      end

      ##
      # Validates the final response body after middleware processing.
      #
      # @param body [String, nil] final response body
      # @return [void]
      # @raise [ResponseTooLarge] if the final body exceeds configured limits
      # @raise [BlockedSurfaceDetected] if the body matches known anti-bot interstitial signatures
      def inspect_body!(body)
        normalized_body = body.to_s
        size = normalized_body.bytesize
        raise_if_too_large!(size, policy.max_decompressed_bytes)
        raise_if_blocked_surface!(normalized_body)
      end

      private

      attr_reader :policy

      def raise_if_blocked_surface!(body)
        signature = Html2rss::BlockedSurface.interstitial_signature_for(body)
        return unless signature

        raise BlockedSurfaceDetected, signature.fetch(:message)
      end

      def raise_if_too_large!(bytes, limit)
        return unless bytes > limit

        raise ResponseTooLarge, "Response exceeded #{limit} bytes"
      end
    end
  end
end
