# frozen_string_literal: true

module Html2rss
  class JsonFeedBuilder
    ##
    # Maps an {Html2rss::RssBuilder::Article} to a JSONFeed 1.1 item hash.
    class Item
      ##
      # @param article [Html2rss::RssBuilder::Article]
      def initialize(article)
        @article = article
      end

      ##
      # @return [Hash, nil] the JSONFeed-compliant item hash
      def to_h
        content = content_fields
        return if content.empty?

        item_payload.merge(content).compact
      end

      private

      attr_reader :article

      ##
      # @return [Hash]
      def item_payload
        {
          id: article.guid,
          url: article.url&.to_s,
          title: article.title,
          image: article.image&.to_s,
          date_published: article.published_at&.iso8601,
          authors: author_array,
          tags:,
          attachments:
        }
      end

      ##
      # @return [Array<Hash>, nil]
      def author_array
        return unless (name = article.author)

        [{ name: }]
      end

      ##
      # JSON Feed items must include content_html or content_text.
      # @return [Hash]
      def content_fields
        description = article.description
        return { content_html: description } if description

        title = article.title
        return { content_text: title } if title

        {}
      end

      ##
      # @return [Array<String>, nil]
      def tags
        cats = article.categories
        cats.empty? ? nil : cats
      end

      ##
      # Maps enclosures to JSONFeed attachment objects.
      # @return [Array<Hash>, nil]
      def attachments
        enclosures = article.enclosures
        return nil if enclosures.empty?

        enclosures.map { |enc| attachment_hash(enc) }
      end

      ##
      # @param enclosure [Html2rss::RssBuilder::Article::Enclosure]
      # @return [Hash]
      def attachment_hash(enclosure)
        size = enclosure.bits_length

        {
          url: enclosure.url.to_s,
          mime_type: enclosure.type,
          size_in_bytes: size&.positive? ? size : nil
        }.compact
      end
    end
  end
end
