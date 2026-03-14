# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Parses Accept headers for feed representation negotiation.
    module FeedAcceptHeader
      MediaRange = Data.define(:type, :subtype, :quality, :position) do
        # @return [Integer]
        def specificity
          return 0 if type == '*' && subtype == '*'
          return 1 if subtype == '*'

          2
        end

        # @param candidate [String]
        # @return [Boolean]
        def matches?(candidate)
          candidate_type, candidate_subtype = candidate.downcase.split('/', 2)
          return true if type == '*' && subtype == '*'
          return candidate_type == type if subtype == '*'

          candidate_type == type && candidate_subtype == subtype
        end
      end

      class << self
        # @param accept_header [String, nil]
        # @param json_media_types [Array<String>]
        # @param rss_media_types [Array<String>]
        # @return [Symbol, nil]
        def preferred_format(accept_header, json_media_types:, rss_media_types:)
          media_ranges = parse(accept_header)
          return nil if media_ranges.empty?

          json_score = best_score(media_ranges, json_media_types)
          rss_score = best_score(media_ranges, rss_media_types)

          return nil unless json_score
          return FeedResponseFormat::JSON_FEED if rss_score.nil?

          (json_score <=> rss_score)&.positive? ? FeedResponseFormat::JSON_FEED : nil
        end

        private

        # @param accept_header [String, nil]
        # @return [Array<MediaRange>]
        def parse(accept_header)
          accept_header.to_s.split(',').filter_map.with_index do |raw_range, position|
            build_media_range(raw_range, position)
          end
        end

        # @param raw_range [String]
        # @param position [Integer]
        # @return [MediaRange, nil]
        def build_media_range(raw_range, position)
          media_type, *parameter_parts = raw_range.strip.downcase.split(';')
          type, subtype = media_type.to_s.split('/', 2)
          return if type.to_s.empty? || subtype.to_s.empty?

          MediaRange.new(
            type:,
            subtype:,
            quality: extract_quality(parameter_parts),
            position:
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

        # @param media_ranges [Array<MediaRange>]
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
