# frozen_string_literal: true

module Html2rss
  ##
  # HtmlExtractor is responsible for extracting details (headline, url, images, etc.)
  # from an article_tag.
  class HtmlExtractor
    # Tags ignored when extracting visible text content from article containers.
    INVISIBLE_CONTENT_TAGS = %w[svg script noscript style template].to_set.freeze
    # Heading tags used to prioritize title extraction.
    HEADING_TAGS = %w[h1 h2 h3 h4 h5 h6].freeze
    # Selector used to derive non-headline description nodes.
    NON_HEADLINE_SELECTOR = (HEADING_TAGS.map { |tag| ":not(#{tag})" } + INVISIBLE_CONTENT_TAGS.to_a).freeze

    # Anchor selector used to identify the canonical article link element.
    MAIN_ANCHOR_SELECTOR = begin
      buf = +'a[href]:not([href=""])'
      %w[# javascript: mailto: tel: file:// sms: data:].each do |prefix|
        buf << %[:not([href^="#{prefix}"])]
      end
      buf.freeze
    end

    class << self
      ##
      # Extracts visible text from a given node and its children.
      #
      # @param tag [Nokogiri::XML::Node] the node from which to extract visible text
      # @param separator [String] separator used to join text fragments (default is a space)
      # @return [String, nil] the concatenated visible text, or nil if none is found
      def extract_visible_text(tag, separator: ' ')
        parts = tag.children.filter_map do |child|
          next unless visible_child?(child)

          raw_text = child.children.empty? ? child.text : extract_visible_text(child)
          text = raw_text&.strip
          text unless text.to_s.empty?
        end

        parts.join(separator).squeeze(' ').strip unless parts.empty?
      end

      private

      def visible_child?(node)
        !INVISIBLE_CONTENT_TAGS.include?(node.name) &&
          !(node.name == 'a' && node['href']&.start_with?('#'))
      end
    end

    ##
    # @param article_tag [Nokogiri::XML::Node] article-like container to extract from
    # @param base_url [String, Html2rss::Url] base url used to resolve relative links
    # @param selected_anchor [Nokogiri::XML::Node, nil] explicit primary anchor for the container
    def initialize(article_tag, base_url:, selected_anchor:)
      raise ArgumentError, 'article_tag is required' unless article_tag

      @article_tag = article_tag
      @base_url = base_url
      @selected_anchor = selected_anchor
    end

    # @return [Hash{Symbol => Object}] extracted article attributes
    def call
      {
        title: extract_title,
        url: extract_url,
        image: extract_image,
        description: extract_description,
        id: generate_id,
        published_at: extract_published_at,
        enclosures: extract_enclosures,
        categories: extract_categories
      }
    end

    private

    attr_reader :article_tag, :base_url, :selected_anchor

    class << self
      ##
      # @param article_tag [Nokogiri::XML::Node] article-like container to search within
      # @return [Nokogiri::XML::Node, nil] first eligible descendant anchor
      def main_anchor_for(article_tag)
        return article_tag if article_tag.name == 'a' && article_tag.matches?(MAIN_ANCHOR_SELECTOR)

        article_tag.at_css(MAIN_ANCHOR_SELECTOR)
      end
    end

    def extract_url
      @extract_url ||= begin
        href = selected_anchor&.[]('href').to_s

        Url.from_relative(href.split('#').first.strip, base_url) unless href.empty?
      end
    end

    def extract_title
      title_source = heading || selected_anchor
      self.class.extract_visible_text(title_source) if title_source
    end

    def heading
      @heading ||= begin
        heading_tags = article_tag.css(HEADING_TAGS.join(',')).group_by(&:name)
        smallest_heading = heading_tags.keys.min
        if smallest_heading
          heading_tags[smallest_heading]&.max_by do |tag|
            self.class.extract_visible_text(tag)&.size.to_i
          end
        end
      end
    end

    def extract_description
      text = self.class.extract_visible_text(article_tag.css(NON_HEADLINE_SELECTOR), separator: '<br>')
      return text if text && !text.empty?

      description = self.class.extract_visible_text(article_tag)
      return nil if description.nil? || description.strip.empty?

      description.strip
    end

    def generate_id
      [
        article_tag['id'],
        article_tag.at_css('[id]')&.attr('id'),
        extract_url&.path,
        extract_url&.query
      ].compact.reject(&:empty?).first
    end

    def extract_image = ImageExtractor.call(article_tag, base_url:)
    def extract_published_at = DateExtractor.call(article_tag)
    def extract_enclosures = EnclosureExtractor.call(article_tag, base_url)
    def extract_categories = CategoryExtractor.call(article_tag)
  end
end
