# frozen_string_literal: true

module Html2rss
  class RequestSession
    ##
    # Carries the runtime request inputs needed to build a RequestSession.
    class RuntimeInput
      ##
      # @param config [Html2rss::Config] validated feed config
      # @return [RuntimeInput] runtime request inputs derived from the config
      def self.from_config(config)
        new(
          url: config.url,
          headers: config.headers,
          request: config.request,
          strategy: config.strategy,
          request_policy: RuntimePolicy.from_config(config)
        )
      end

      ##
      # @param url [String, Html2rss::Url] initial request URL
      # @param headers [Hash] normalized request headers
      # @param request [Hash] validated request options for strategies
      # @param strategy [Symbol] request strategy to use for the session
      # @param request_policy [RequestService::Policy] request policy for the session
      def initialize(url:, headers:, request:, strategy:, request_policy:)
        @url = Html2rss::Url.from_absolute(url)
        @headers = normalize_headers(headers).freeze
        @request = normalize_request(request).freeze
        @strategy = strategy
        @request_policy = request_policy
        freeze
      end

      ##
      # @return [Html2rss::Url] initial request URL
      attr_reader :url

      ##
      # @return [Hash] normalized request headers
      attr_reader :headers

      ##
      # @return [Hash] validated request options for strategies
      attr_reader :request

      ##
      # @return [Symbol] request strategy to use for the session
      attr_reader :strategy

      ##
      # @return [RequestService::Policy] policy derived from the runtime request inputs
      attr_reader :request_policy

      private

      def normalize_headers(headers)
        headers.to_h do |key, value|
          [key.to_s, value]
        end
      end

      def normalize_request(request)
        normalized = HashUtil.deep_symbolize_keys(request, context: 'request')
        HashUtil.assert_symbol_keys!(normalized, context: 'request')
        normalized
      end
    end
  end
end
