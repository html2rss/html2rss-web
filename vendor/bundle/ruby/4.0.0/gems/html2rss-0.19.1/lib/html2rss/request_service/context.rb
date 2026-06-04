# frozen_string_literal: true

module Html2rss
  class RequestService
    ##
    # Holds information needed to send requests to websites.
    # To be passed down to the RequestService's strategies.
    class Context
      ##
      # @param url [String, Html2rss::Url] the URL to request
      # @param headers [Hash] HTTP request headers
      # @param request [Hash] request specific options passed to strategies
      # @param request_options [Hash] runtime request options
      # @option request_options [Symbol] :relation why this request is being made
      # @option request_options [String, Html2rss::Url, nil] :origin_url originating URL for same-origin checks
      # @option request_options [Policy] :policy runtime request policy
      # @option request_options [Budget] :budget shared request budget for the feed build
      # @raise [ArgumentError] if policy or budget is explicitly nil
      def initialize(url:, headers: {}, request: {}, **request_options)
        @url = Html2rss::Url.from_absolute(url)
        @headers = normalize_headers(headers).freeze
        @request = normalize_request(request).freeze
        assign_request_options(request_options)
      end

      # @return [Html2rss::Url] the parsed and normalized URL
      attr_reader :url

      # @return [Hash] the HTTP request headers
      attr_reader :headers

      # @return [Hash] the request specific options
      attr_reader :request

      # @return [Hash] browserless specific options
      def browserless = request.fetch(:browserless, {})

      # @return [Hash, nil] preload options for browserless requests
      def browserless_preload = browserless[:preload]

      # @return [Symbol] the request relation
      attr_reader :relation

      # @return [Html2rss::Url] the initial URL for the feed build
      attr_reader :origin_url

      # @return [Policy] the runtime request policy
      attr_reader :policy

      # @return [Budget] the shared request budget
      attr_reader :budget

      ##
      # Builds a follow-up request context sharing headers, budget, and policy.
      #
      # @param url [String, Html2rss::Url] the follow-up URL
      # @param relation [Symbol] why the follow-up is being made
      # @param origin_url [String, Html2rss::Url] effective origin for same-origin checks
      # @return [Context] derived request context
      def follow_up(url:, relation:, origin_url: self.origin_url)
        self.class.new(
          url:,
          headers:,
          request:,
          relation:,
          origin_url:,
          policy:,
          budget:
        )
      end

      private

      def assign_request_options(request_options)
        @relation = request_options.fetch(:relation, :initial)
        @policy = request_options.fetch(:policy, Policy.default)
        raise ArgumentError, 'policy must not be nil' if @policy.nil?

        @origin_url = normalized_origin_url(request_options[:origin_url])
        @budget = request_options.fetch(:budget) { Budget.new(max_requests: policy.max_requests) }
        raise ArgumentError, 'budget must not be nil' if @budget.nil?
      end

      def normalized_origin_url(origin_url)
        source = origin_url || @url
        Html2rss::Url.from_absolute(source)
      end

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
