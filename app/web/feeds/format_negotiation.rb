# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Negotiates RSS vs JSON Feed from path extension and Accept headers.
      module FormatNegotiation
        JSON_FEED = :json_feed
        RSS = :rss

        JSON_CONTENT_TYPE = 'application/feed+json'
        RSS_CONTENT_TYPE = 'application/xml'
        TEXT_PLAIN_CONTENT_TYPE = 'text/plain; charset=utf-8'

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
          # Negotiates RSS vs JSON Feed for a request (path extension, then Accept).
          #
          # @param request [Rack::Request]
          # @return [Symbol] :rss or :json_feed
          def format_for_request(request)
            from_path(request_path(request)) || from_accept(accept_header(request)) || RSS
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

          # @param request [Rack::Request]
          # @return [String]
          def request_path(request)
            path = request.respond_to?(:env) ? request.env['PATH_INFO'] : nil
            return path.to_s unless request_path_fallback?(request, path)

            request.path_info.to_s
          end

          private

          # @param path [String]
          # @return [Symbol, nil] format implied by known extension.
          def from_path(path)
            PATH_FORMATS.each do |suffix, format|
              return format if path.end_with?(suffix)
            end

            nil
          end

          # Parses Accept header and returns the preferred format based on priority.
          #
          # @param accept_header [String, nil]
          # @return [Symbol, nil] preferred format (:json_feed, or nil meaning fallback to rss)
          def from_accept(accept_header)
            media_ranges = parse_accept(accept_header)
            return nil if media_ranges.empty?

            json_score = best_score(media_ranges, JSON_MEDIA_TYPES)
            rss_score = best_score(media_ranges, RSS_MEDIA_TYPES)

            return nil unless json_score
            return JSON_FEED if rss_score.nil?

            (json_score <=> rss_score)&.positive? ? JSON_FEED : nil
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
          # @return [Array<Html2rss::Web::Feeds::FormatNegotiation::MediaRange>]
          def parse_accept(accept_header)
            accept_header.to_s.split(',').filter_map.with_index do |raw_range, position|
              build_media_range(raw_range, position)
            end
          end

          # @param raw_range [String]
          # @param position [Integer]
          # @return [Html2rss::Web::Feeds::FormatNegotiation::MediaRange, nil]
          def build_media_range(raw_range, position)
            media_type, *parameter_parts = raw_range.strip.downcase.split(';')
            type, subtype = media_type.to_s.split('/', 2)
            return if type.to_s.empty? || subtype.to_s.empty?

            MediaRange.new(
              type: type,
              subtype: subtype,
              quality: extract_quality(parameter_parts),
              position: position
            )
          end

          # @param parameter_parts [Array<String>]
          # @return [Float]
          def extract_quality(parameter_parts)
            raw_value = parameter_parts
                        .map(&:strip)
                        .find { |part| part.start_with?('q=') }
                        &.split('=', 2)
                        &.last
            quality = raw_value ? Float(raw_value) : 1.0
            quality.clamp(0.0, 1.0)
          rescue ArgumentError
            1.0
          end

          # @param media_ranges [Array<Html2rss::Web::Feeds::FormatNegotiation::MediaRange>]
          # @param candidates [Array<String>]
          # @return [Array(Float, Integer, Integer), nil]
          def best_score(media_ranges, candidates)
            media_ranges
              .filter { |range| range.quality.positive? && candidates.any? { |candidate| range.matches?(candidate) } }
              .map { |range| [range.quality, range.specificity, -range.position] }
              .max
          end
        end
      end
    end
  end
end
