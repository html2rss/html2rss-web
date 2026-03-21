# frozen_string_literal: true

require 'digest'
require 'uri'

module Html2rss
  module Web
    ##
    # Sanitizes request and detail payloads before structured logging.
    module LogSanitizer
      FEED_TOKEN_ROUTE = %r{\A(/api/v1/feeds/)([^/.?]+)(\.(?:json|xml|rss))?\z}

      class << self
        # @param path [String, nil]
        # @return [String, nil]
        def sanitize_path(path)
          return if path.nil?

          path.to_s.gsub(FEED_TOKEN_ROUTE, '\1[REDACTED]\3')
        end

        # @param details [Hash]
        # @return [Hash]
        def sanitize_details(details)
          details.each_with_object({}) do |(key, value), sanitized|
            sanitized[key] = sanitize_value(key, value)
          end
        end

        private

        # @param key [Object]
        # @param value [Object]
        # @return [Object]
        def sanitize_value(key, value)
          return sanitize_url(value) if key.to_sym == :url
          return sanitize_details(value) if value.is_a?(Hash)
          return value.map { |entry| sanitize_value(key, entry) } if value.is_a?(Array)

          value
        end

        # @param value [Object]
        # @return [Hash{Symbol=>Object}, Object]
        def sanitize_url(value)
          url = value.to_s
          return value if url.empty?

          uri = URI.parse(url)
          {
            host: uri.host,
            scheme: uri.scheme,
            hash: Digest::SHA256.hexdigest(url)[0..11]
          }.compact
        rescue URI::InvalidURIError
          { hash: Digest::SHA256.hexdigest(url)[0..11] }
        end
      end
    end
  end
end
