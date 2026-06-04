# frozen_string_literal: true

require 'nokogiri'

module Html2rss
  class AutoSource
    module Scraper
      ##
      # Scrapes article-like blocks from plain HTML by looking for repeated link
      # structures when richer structured data is unavailable.
      #
      # The approach is intentionally heuristic:
      # 1. collect repeated anchor paths
      # 2. walk upward to a shared container shape
      # 3. extract the best anchor found inside each container
      #
      # This scraper is broader and noisier than `SemanticHtml`, so it acts as a
      # fallback for pages without stronger semantic signals.
      class Html
        include Enumerable

        # Elements ignored when traversing potential article containers.
        TAGS_TO_IGNORE = /(nav|footer|header|svg|script|style)/i

        # Minimum selector frequency required to treat a path as a stable list signal.
        DEFAULT_MINIMUM_SELECTOR_FREQUENCY = 2
        # Number of most frequent selectors kept for container extraction.
        DEFAULT_USE_TOP_SELECTORS = 5

        ##
        # @return [Symbol] config key used to enable or configure this scraper
        def self.options_key = :html

        ##
        # Probes whether the document appears to contain repeated anchor
        # structures that this fallback scraper can cluster into article-like
        # containers.
        #
        # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
        # @return [Boolean] true when the scraper can likely extract articles
        def self.articles?(parsed_body)
          new(parsed_body, url: '').any?
        end

        ##
        # Simplify an XPath selector by removing the index notation.
        # This keeps repeated anchor paths comparable across sibling blocks.
        #
        # @param xpath [String] original XPath
        # @return [String] XPath without positional indexes
        def self.simplify_xpath(xpath)
          xpath.gsub(/\[\d+\]/, '')
        end

        # @param parsed_body [Nokogiri::HTML::Document] The parsed HTML document.
        # @param url [String] The base URL.
        # @param extractor [Class] The extractor class to handle article extraction.
        # @param opts [Hash] Additional options.
        # @option opts [Integer] :minimum_selector_frequency minimum count before a selector is considered stable
        # @option opts [Integer] :use_top_selectors number of top selectors to keep
        def initialize(parsed_body, url:, extractor: HtmlExtractor, **opts)
          @parsed_body = parsed_body
          @url = url
          @extractor = extractor
          @opts = opts
        end

        attr_reader :parsed_body

        ##
        # @yieldparam [Hash] The scraped article hash
        # @return [Enumerator] Enumerator for the scraped articles
        def each
          return enum_for(:each) unless block_given?

          each_article_tag do |article_tag|
            article_hash = extract_article(article_tag)
            yield article_hash if article_hash
          end
        end

        ##
        # Decides whether a traversed node has reached a useful article-like
        # boundary for the generic HTML scraper.
        #
        # The predicate prefers containers that add surrounding link context,
        # which helps the scraper move from a leaf anchor toward a repeated
        # teaser/card wrapper.
        #
        # @param node [Nokogiri::XML::Node] candidate boundary node
        # @return [Boolean] true when the node is a good extraction boundary
        def article_tag_condition?(node)
          # Ignore tags that are below a tag which is in TAGS_TO_IGNORE.
          return false if node.path.match?(TAGS_TO_IGNORE)
          return true if %w[body html].include?(node.name)
          return false unless (parent = node.parent)

          anchor_count(parent) > anchor_count(node)
        end

        private

        ##
        # Find relevant anchors in root.
        # @return [Set<String>] The set of XPath selectors
        def selectors
          @selectors ||= Hash.new(0).tap do |selectors|
            each_relevant_anchor { |node| increment_selector_count(selectors, node) }
          end
        end

        ##
        # Filter the frequent selectors by the minimum_selector_frequency and use_top_selectors.
        # @return [Array<String>] The filtered selectors
        def filtered_selectors
          selectors.select { |_selector, count| count >= minimum_selector_frequency }
                   .max_by(use_top_selectors, &:last)
                   .map(&:first)
        end

        def minimum_selector_frequency = @opts[:minimum_selector_frequency] || DEFAULT_MINIMUM_SELECTOR_FREQUENCY
        def use_top_selectors = @opts[:use_top_selectors] || DEFAULT_USE_TOP_SELECTORS

        def anchor_count(node)
          @anchor_counts ||= {}
          @anchor_counts[node.path] ||= node.name == 'a' ? 1 : node.css('a').size
        end

        def each_relevant_anchor
          return enum_for(:each_relevant_anchor) unless block_given?

          traversal_root&.traverse do |node|
            yield node if relevant_anchor?(node)
          end
        end

        def relevant_anchor?(node)
          node.element? && node.name == 'a' && !String(node['href']).empty?
        end

        def increment_selector_count(selectors, node)
          path = self.class.simplify_xpath(node.path)
          selectors[path] += 1 unless path.match?(TAGS_TO_IGNORE)
        end

        def traversal_root
          parsed_body.at_css('body, html') || parsed_body.root
        end

        def each_article_tag
          return enum_for(:each_article_tag) unless block_given?

          filtered_selectors.each do |selector|
            parsed_body.xpath(selector).each do |selected_tag|
              article_tag = article_tag_for(selected_tag)
              yield article_tag if article_tag
            end
          end
        end

        def article_tag_for(selected_tag)
          return if selected_tag.path.match?(Html::TAGS_TO_IGNORE)

          HtmlNavigator.parent_until_condition(selected_tag, method(:article_tag_condition?))
        end

        def extract_article(article_tag)
          selected_anchor = HtmlExtractor.main_anchor_for(article_tag)
          return unless selected_anchor

          @extractor.new(article_tag, base_url: @url, selected_anchor:).call
        end
      end
    end
  end
end
