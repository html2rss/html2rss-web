# frozen_string_literal: true

module Html2rss
  ##
  # CategoryExtractor is responsible for extracting categories from HTML elements
  # by looking for CSS class names containing common category-related terms.
  class CategoryExtractor
    # Common category-related terms to look for in class names
    CATEGORY_TERMS = %w[category tag topic section label theme subject].freeze

    # CSS selectors to find elements with category-related class names
    CATEGORY_SELECTORS = CATEGORY_TERMS.map { |term| "[class*=\"#{term}\"]" }.freeze

    # Regex pattern for matching category-related attribute names
    CATEGORY_ATTR_PATTERN = /#{CATEGORY_TERMS.join('|')}/i

    ##
    # Extracts categories from the given article tag by looking for elements
    # with class names containing common category-related terms.
    #
    # @param article_tag [Nokogiri::XML::Element] The article element to extract categories from
    # @return [Array<String>] Array of category strings, empty if none found
    def self.call(article_tag)
      return [] unless article_tag

      # Single optimized traversal that extracts all category types
      extract_all_categories(article_tag)
        .map(&:strip)
        .reject(&:empty?)
    end

    ##
    # Optimized single DOM traversal that extracts all category types.
    #
    # @param article_tag [Nokogiri::XML::Element] The article element
    # @return [Set<String>] Set of category strings
    def self.extract_all_categories(article_tag)
      Set.new.tap do |categories|
        article_tag.css('*').each do |element|
          # Extract text categories from elements with category-related class names
          categories.merge(extract_text_categories(element)) if element['class']&.match?(CATEGORY_ATTR_PATTERN)

          # Extract data categories from all elements
          categories.merge(extract_element_data_categories(element))
        end
      end
    end

    ##
    # Extracts categories from data attributes of a single element.
    #
    # @param element [Nokogiri::XML::Element] metadata element that may contain category links
    # @return [Set<String>] Set of category strings
    def self.extract_element_data_categories(element)
      Set.new.tap do |categories|
        element.attributes.each_value do |attr|
          next unless attr.name.match?(CATEGORY_ATTR_PATTERN)

          value = attr.value&.strip
          categories.add(value) if value && !value.empty?
        end
      end
    end

    ##
    # Extracts text-based categories from elements, splitting content into discrete values.
    #
    # @param element [Nokogiri::XML::Element] metadata element whose text may contain delimiters
    # @return [Set<String>] Set of category strings
    def self.extract_text_categories(element)
      anchor_values = element.css('a').filter_map do |node|
        HtmlExtractor.extract_visible_text(node)
      end
      return Set.new(anchor_values.reject(&:empty?)) if anchor_values.any?

      text = HtmlExtractor.extract_visible_text(element)
      return Set.new unless text

      Set.new(text.split(/\n+/).map(&:strip).reject(&:empty?))
    end
  end
end
