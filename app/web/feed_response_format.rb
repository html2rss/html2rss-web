# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Resolves feed response formats from request paths and Accept headers.
    module FeedResponseFormat
      JSON_FEED = :json_feed
      RSS = :rss

      JSON_CONTENT_TYPE = 'application/feed+json'
      RSS_CONTENT_TYPE = 'application/xml'

      PATH_FORMATS = {
        '.json' => JSON_FEED,
        '.rss' => RSS,
        '.xml' => RSS
      }.freeze

      JSON_MEDIA_TYPES = [
        'application/feed+json',
        'application/json'
      ].freeze

      RSS_MEDIA_TYPES = [
        'application/rss+xml',
        'application/xml',
        'text/xml'
      ].freeze

      class << self
        # @param request [Rack::Request]
        # @return [Symbol] negotiated feed format.
        def for_request(request)
          from_path(request_path(request)) || from_accept(accept_header(request)) || RSS
        end

        # @param path [String]
        # @return [Symbol, nil] format implied by known extension.
        def from_path(path)
          PATH_FORMATS.each do |suffix, format|
            return format if path.end_with?(suffix)
          end

          nil
        end

        # @param value [String]
        # @return [String] input without a known feed extension suffix.
        def strip_known_extension(value)
          string = value.to_s

          PATH_FORMATS.each_key do |suffix|
            return string.delete_suffix(suffix) if string.end_with?(suffix)
          end

          string
        end

        # @param format [Symbol]
        # @return [String] HTTP content type for the negotiated format.
        def content_type(format)
          format == JSON_FEED ? JSON_CONTENT_TYPE : RSS_CONTENT_TYPE
        end

        private

        # @param request [Rack::Request]
        # @return [String]
        def request_path(request)
          path = request.respond_to?(:env) ? request.env['PATH_INFO'] : nil
          return path.to_s unless request_path_fallback?(request, path)

          request.path_info.to_s
        end

        # @param request [Rack::Request]
        # @return [String, nil]
        def accept_header(request)
          return request.get_header('HTTP_ACCEPT') unless request.respond_to?(:env)

          request.env['HTTP_ACCEPT'] || request.get_header('HTTP_ACCEPT')
        end

        # @param request [Rack::Request]
        # @param path [String, nil]
        # @return [Boolean]
        def request_path_fallback?(request, path)
          path.to_s.empty? && request.respond_to?(:path_info)
        end

        # @param accept_header [String, nil]
        # @return [Symbol, nil]
        def from_accept(accept_header)
          FeedAcceptHeader.preferred_format(
            accept_header,
            json_media_types: JSON_MEDIA_TYPES,
            rss_media_types: RSS_MEDIA_TYPES
          )
        end
      end
    end
  end
end
