# frozen_string_literal: true

require 'zlib'
require 'sanitize'
require 'nokogiri'

module Html2rss
  class RssBuilder
    ##
    # Article is a simple data object representing an article extracted from a page.
    # It is enumerable and responds to all keys specified in PROVIDED_KEYS.
    class Article
      include Enumerable
      include Comparable

      # Allowed article attributes accepted by the value object constructor.
      PROVIDED_KEYS = %i[id title description url image author guid published_at enclosures categories scraper].freeze
      # Separator used to build deterministic deduplication fingerprints.
      DEDUP_FINGERPRINT_SEPARATOR = '#!/'

      # @param options [Hash{Symbol => String}]
      # @option options [String] :id stable article identifier
      # @option options [String] :title article title
      # @option options [String] :description article description/content
      # @option options [String, Html2rss::Url] :url canonical article URL
      # @option options [String, Html2rss::Url] :image image URL for fallback enclosure rendering
      # @option options [String] :author author name
      # @option options [String] :guid explicit GUID override
      # @option options [String, Time, DateTime] :published_at publication timestamp
      # @option options [Array<Hash{Symbol => Object}>] :enclosures enclosure attribute hashes
      # @option options [Array<String>] :categories category labels
      # @option options [Class] :scraper scraper class that produced the article
      def initialize(**options)
        @to_h = {}
        options.each_pair { |key, value| @to_h[key] = value.freeze if value }
        @to_h.freeze

        return unless (unknown_keys = options.keys - PROVIDED_KEYS).any?

        Log.warn "Article: unknown keys found: #{unknown_keys.join(', ')}"
      end

      # Checks if the article is valid based on the presence of URL, ID, and either title or description.
      # @return [Boolean] True if the article is valid, otherwise false.
      def valid?
        !url.to_s.empty? && (!title.to_s.empty? || !description.to_s.empty?) && !id.to_s.empty?
      end

      # @yield [key, value]
      # @return [Enumerator] if no block is given
      def each
        return enum_for(:each) unless block_given?

        PROVIDED_KEYS.each { |key| yield(key, public_send(key)) }
      end

      # @return [String, nil] stable article identifier
      def id = blank_string_to_nil(@to_h[:id])

      # @return [String, nil] article title
      def title = blank_string_to_nil(@to_h[:title])

      # @return [String] rendered article description
      def description
        @description ||= Rendering::DescriptionBuilder.new(
          base: @to_h[:description],
          title:,
          url:,
          enclosures:,
          image:
        ).call
      end

      # @return [Url, nil]
      def url
        @url ||= Url.sanitize(@to_h[:url])
      end

      # @return [Url, nil]
      def image
        @image ||= Url.sanitize(@to_h[:image])
      end

      # @return [String, nil]
      def author = blank_string_to_nil(@to_h[:author])

      # Generates a unique identifier based on the URL and ID using CRC32.
      # @return [String]
      def guid
        @guid ||= Zlib.crc32(fetch_guid).to_s(36).encode('utf-8')
      end

      ##
      # Returns a deterministic fingerprint used to detect duplicate articles.
      #
      # @return [String, Integer]
      def deduplication_fingerprint
        dedup_from_url || dedup_from_id || dedup_from_guid || hash
      end

      # @return [Array<Html2rss::RssBuilder::Enclosure>] normalized enclosure objects
      def enclosures
        @enclosures ||= Array(@to_h[:enclosures])
                        .map { |enclosure| Html2rss::RssBuilder::Enclosure.new(**enclosure) }
      end

      # @return [Html2rss::RssBuilder::Enclosure, nil]
      def enclosure
        return @enclosure if defined?(@enclosure)

        case (object = @to_h[:enclosures]&.first)
        when Hash
          @enclosure = Html2rss::RssBuilder::Enclosure.new(**object)
        when nil
          @enclosure = Html2rss::RssBuilder::Enclosure.new(url: image) if image
        else
          Log.warn "Article: unknown enclosure type: #{object.class}"
        end
      end

      # @return [Array<String>] normalized, unique category names
      def categories
        @categories ||= @to_h[:categories].dup.to_a.tap do |categories|
          categories.map! { |category| category.to_s.strip }
          categories.reject!(&:empty?)
          categories.uniq!
        end
      end

      # Parses and returns the published_at time.
      # @return [DateTime, nil]
      def published_at
        return if (string = @to_h[:published_at].to_s.strip).empty?

        @published_at ||= DateTime.parse(string)
      rescue ArgumentError
        nil
      end

      # @return [Class, nil] scraper class that produced this article
      def scraper
        @to_h[:scraper]
      end

      # @param other [Object] value compared against this article
      # @return [Integer, nil] comparison result for compatible Article values
      def <=>(other)
        return nil unless other.is_a?(Article)

        0 if other.all? { |key, value| value == public_send(key) ? public_send(key) <=> value : false }
      end

      private

      def dedup_from_url
        return unless (value = url)

        [value.to_s, id].compact.join(DEDUP_FINGERPRINT_SEPARATOR)
      end

      def dedup_from_id
        return if id.to_s.empty?

        id
      end

      def dedup_from_guid
        value = guid
        return if value.to_s.empty?

        [value, title, description].compact.join(DEDUP_FINGERPRINT_SEPARATOR)
      end

      def fetch_guid
        guid = @to_h[:guid].map { |s| s.to_s.strip }.reject(&:empty?).join if @to_h[:guid].is_a?(Array)

        guid || [url, id].join('#!/')
      end

      def blank_string_to_nil(value)
        return if value.is_a?(String) && value.strip.empty?

        value
      end
    end
  end
end
