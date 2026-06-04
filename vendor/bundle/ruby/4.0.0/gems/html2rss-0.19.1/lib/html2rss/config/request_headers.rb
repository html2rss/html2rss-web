# frozen_string_literal: true

module Html2rss
  class Config
    ##
    # Normalizes HTTP headers for outgoing requests.
    # Ensures a browser-like baseline while respecting caller overrides.
    class RequestHeaders
      # Browser-like default `Accept` header value.
      DEFAULT_ACCEPT = %w[
        text/html
        application/xhtml+xml
        application/xml;q=0.9
        image/avif
        image/webp
        image/apng
        */*;q=0.8
      ].join(',')

      # Browser-like default `User-Agent` header value.
      DEFAULT_USER_AGENT = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'AppleWebKit/537.36 (KHTML, like Gecko)',
        'Chrome/123.0.0.0',
        'Safari/537.36'
      ].join(' ')

      # Baseline browser-like header set used for outbound requests.
      DEFAULT_HEADERS = {
        'Accept' => DEFAULT_ACCEPT,
        'Cache-Control' => 'max-age=0',
        'Connection' => 'keep-alive',
        'Sec-Fetch-Dest' => 'document',
        'Sec-Fetch-Mode' => 'navigate',
        'Sec-Fetch-Site' => 'none',
        'Sec-Fetch-User' => '?1',
        'Upgrade-Insecure-Requests' => '1',
        'User-Agent' => DEFAULT_USER_AGENT
      }.freeze

      class << self
        ##
        # @return [Hash{String => String}] the unmodified default header set
        def browser_defaults
          DEFAULT_HEADERS.dup
        end

        ##
        # Normalizes the provided headers while applying Html2rss defaults.
        #
        # @param headers [Hash, nil] caller provided headers
        # @param channel_language [String, nil] language defined on the channel
        # @param url [String] request URL used to infer the Host header
        # @return [Hash{String => String}] normalized HTTP headers
        def normalize(headers, channel_language:, url:)
          new(headers || {}, channel_language:, url:).to_h
        end
      end

      # @param headers [Hash{String, Symbol => String}] caller-provided headers
      # @param channel_language [String, nil] channel language hint for Accept-Language
      # @param url [String, Html2rss::Url, nil] request URL used to infer Host
      def initialize(headers, channel_language:, url:)
        @headers = headers
        @channel_language = channel_language
        @url = url
      end

      ##
      # @return [Hash{String => String}] normalized HTTP headers
      def to_h
        defaults = DEFAULT_HEADERS.dup
        normalized = normalize_custom_headers(headers)

        accept_override = normalized.delete('Accept')
        defaults.merge!(normalized)

        defaults['Accept'] = normalize_accept(accept_override)
        defaults['Accept-Language'] = build_accept_language
        defaults['Host'] ||= request_host

        defaults.compact
      end

      private

      attr_reader :headers, :channel_language, :url

      def normalize_custom_headers(custom)
        custom.transform_keys { canonicalize(_1) }
      end

      def canonicalize(key)
        key.to_s.split('-').map!(&:capitalize).join('-')
      end

      def normalize_accept(override)
        return DEFAULT_ACCEPT if override.nil? || override.empty?

        values = accept_values(DEFAULT_ACCEPT)

        accept_values(override).reverse_each do |value|
          next if values.include?(value)

          values.unshift(value)
        end

        values.join(',')
      end

      def accept_values(header)
        header.split(',').map!(&:strip).reject(&:empty?)
      end

      def build_accept_language
        language = channel_language.to_s.strip
        return 'en-US,en;q=0.9' if language.empty?

        normalized = language.tr('_', '-')
        primary, region = normalized.split('-', 2)
        primary = primary.downcase
        region = region&.upcase

        return primary if region.nil?

        "#{primary}-#{region},#{primary};q=0.9"
      end

      def request_host
        return nil if url.nil? || url.empty?

        Html2rss::Url.from_absolute(url).host
      end
    end
  end
end
