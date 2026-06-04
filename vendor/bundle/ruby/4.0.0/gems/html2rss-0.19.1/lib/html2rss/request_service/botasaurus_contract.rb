# frozen_string_literal: true

require 'json'

##
# Main html2rss namespace.
module Html2rss
  ##
  # Request transport orchestration and strategies.
  class RequestService
    ##
    # Maps html2rss request/response handling to the botasaurus-scrape-api contract.
    class BotasaurusContract
      # Default Botasaurus scrape options when no explicit config is provided.
      DEFAULT_OPTIONS = {
        navigation_mode: 'auto',
        max_retries: 2,
        headless: false
      }.freeze

      # Allowlisted request.botasaurus keys forwarded to upstream.
      OPTION_KEYS = %i[
        navigation_mode
        max_retries
        wait_for_selector
        wait_timeout_seconds
        block_images
        block_images_and_css
        wait_for_complete_page_load
        headless
        proxy
        user_agent
        window_size
        lang
      ].freeze

      # Parsed Botasaurus response wrapper.
      class ParsedResponse
        # Fallback headers when upstream omits response headers.
        DEFAULT_HEADERS = { 'content-type' => 'text/html' }.freeze

        # @param payload [Hash{String => Object}] parsed Botasaurus response payload
        # @param transport_status [Integer] HTTP status returned by Botasaurus
        def initialize(payload:, transport_status:)
          @payload = payload
          @transport_status = transport_status
        end

        # @return [Boolean] true when upstream classified request as challenge blocked
        def challenge_block? = error_category == 'challenge_block'

        # @return [Boolean] true when upstream returned non-200 or an error payload
        def upstream_failure?
          status != 200 || error_message?
        end

        # @return [String] normalized challenge error message
        def challenge_message
          error || 'Botasaurus challenge block detected.'
        end

        # @return [String] actionable upstream failure summary
        def upstream_failure_message
          details = ["status=#{status}"]
          details << "error_category=#{error_category}" if error_category
          details << "error=#{error}" if error
          details << "request_id=#{request_id}" if request_id
          "Botasaurus scrape failed (#{details.join(', ')})."
        end

        # @return [String] rendered HTML body from Botasaurus
        # @raise [BotasaurusConnectionFailed] when html is missing
        def html
          value = payload['html']
          raise BotasaurusConnectionFailed, "Botasaurus response missing required 'html' field" if value.nil?

          value.to_s
        end

        # @return [Hash{String => String}] normalized response headers
        def headers
          raw_headers = payload['headers']
          return DEFAULT_HEADERS.dup unless raw_headers.is_a?(Hash) && raw_headers.any?

          raw_headers.to_h { |key, value| [key.to_s, value.to_s] }
        end

        # @return [Integer] resolved status code (payload status_code or transport status)
        def status
          status_code = payload['status_code']
          status_code.is_a?(Integer) ? status_code : transport_status
        end

        # @return [String, nil] final URL reported by upstream
        def final_url = payload['final_url']

        private

        attr_reader :payload, :transport_status

        def error = payload['error']

        def request_id = payload['request_id']

        def error_category = payload['error_category']

        def error_message?
          value = error
          value.is_a?(String) ? !value.empty? : !value.nil?
        end
      end

      ##
      # @param url [Html2rss::Url] canonical URL to scrape
      # @param options [Hash] validated request.botasaurus options
      # @option options [String] :navigation_mode
      # @option options [Integer] :max_retries
      # @option options [String] :wait_for_selector
      # @option options [Integer] :wait_timeout_seconds
      # @option options [Boolean] :block_images
      # @option options [Boolean] :block_images_and_css
      # @option options [Boolean] :wait_for_complete_page_load
      # @option options [Boolean] :headless
      # @option options [String] :proxy
      # @option options [String] :user_agent
      # @option options [Array<Integer>] :window_size
      # @option options [String] :lang
      def initialize(url:, options: {})
        @url = url
        @options = options
      end

      # @return [Hash] payload for POST /scrape
      def request_payload
        DEFAULT_OPTIONS.merge(filtered_options).merge(url: url.to_s)
      end

      # @param transport_response [Faraday::Response] upstream HTTP response
      # @return [ParsedResponse]
      # @raise [BotasaurusConnectionFailed] when payload is not valid JSON object
      def parse_response(transport_response)
        payload = JSON.parse(transport_response.body.to_s)
        raise BotasaurusConnectionFailed, 'Botasaurus response must be a JSON object' unless payload.is_a?(Hash)

        ParsedResponse.new(payload:, transport_status: transport_response.status)
      rescue JSON::ParserError => error
        raise BotasaurusConnectionFailed, "Botasaurus response JSON parse failed: #{error.message}"
      end

      private

      attr_reader :url, :options

      def filtered_options
        OPTION_KEYS.each_with_object({}) do |key, normalized|
          normalized[key] = options[key] if options.key?(key)
        end
      end
    end
  end
end
