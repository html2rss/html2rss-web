# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Shared response builders for API v1.
        #
        # A single helper keeps success payload shape stable across endpoints.
        module Response
          class << self
            # Builds a success payload and optionally mutates Rack response.
            #
            # @param data [Hash{Symbol=>Object}] endpoint-specific payload.
            # @param meta [Hash{Symbol=>Object}, nil] optional metadata.
            # @param response [Hash, nil] mutable Rack response.
            # @param status [Integer] HTTP status to set when response is present.
            # @return [Hash{Symbol=>Object}] normalized API success body.
            # @option return [Boolean] :success always true for this helper.
            # @option return [Hash] :data endpoint payload.
            # @option return [Hash] :meta optional metadata block.
            def success(data:, meta: nil, response: nil, status: 200)
              response['Content-Type'] = 'application/json' if response
              response.status = status if response

              payload = { success: true, data: data }
              payload[:meta] = meta if meta
              payload
            end
          end
        end
      end
    end
  end
end
