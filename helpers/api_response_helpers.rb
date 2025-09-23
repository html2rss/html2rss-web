# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Shared response helpers for API v1 modules
    # Provides consistent JSON response formatting
    module ApiResponseHelpers
      module_function

      ##
      # Create a successful JSON response
      # @param data [Hash] response data
      # @param meta [Hash] additional metadata
      # @return [Hash] formatted response
      def success_response(data, meta = {})
        {
          success: true,
          data: data,
          meta: {
            timestamp: Time.now.iso8601,
            version: '1.0.0',
            **meta
          }
        }
      end

      ##
      # Create an error JSON response
      # @param message [String] error message
      # @param code [String] error code
      # @param status [Integer] HTTP status code
      # @return [Hash] formatted error response
      def error_response(message, code = 'ERROR', status = 500)
        {
          success: false,
          error: {
            message: message,
            code: code,
            status: status
          },
          data: {},
          meta: {
            timestamp: Time.now.iso8601,
            version: '1.0.0'
          }
        }
      end

      ##
      # Create a paginated response
      # @param items [Array] list of items
      # @param total [Integer] total count
      # @param meta [Hash] additional metadata
      # @return [Hash] formatted paginated response
      def paginated_response(items, total, meta = {})
        success_response(
          { items: items },
          {
            total: total,
            count: items.count,
            **meta
          }
        )
      end
    end
  end
end
