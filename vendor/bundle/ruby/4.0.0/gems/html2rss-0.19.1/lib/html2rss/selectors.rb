# frozen_string_literal: true

require 'nokogiri'

module Html2rss
  ##
  # This scraper is designed to scrape articles from a given HTML page using CSS
  # selectors defined in the feed config.
  #
  # It supports the traditional feed configs that html2rss originally provided,
  # ensuring compatibility with existing setups.
  #
  # Additionally, it uniquely offers the capability to convert JSON into XML,
  # extending its versatility for diverse data processing workflows.
  class Selectors # rubocop:disable Metrics/ClassLength
    class InvalidSelectorName < Html2rss::Error; end

    include Enumerable

    # A context instance passed to item extractors and post-processors.
    Context = Struct.new('Context', :options, :item, :config, :scraper, keyword_init: true) # rubocop:disable Style/RedundantStructKeywordInit

    # Default selectors options merged into user configuration.
    DEFAULT_CONFIG = { items: { enhance: true } }.freeze

    # Selector key that points to the root list of article nodes.
    ITEMS_SELECTOR_KEY = :items
    # Supported RSS item attributes extractable through selectors.
    ITEM_TAGS = %i[title url description author comments published_at guid enclosure categories].freeze
    # Item attributes that require dedicated extraction logic.
    SPECIAL_ATTRIBUTES = Set[:guid, :enclosure, :categories].freeze

    # Mapping of new attribute names to their legacy names for backward compatibility.
    RENAMED_ATTRIBUTES = { published_at: %i[updated pubDate] }.freeze

    ##
    # Initializes a new Selectors instance.
    #
    # @param response [RequestService::Response] The response object.
    # @param selectors [Hash] A hash of CSS selectors.
    # @param time_zone [String] Time zone string used for date parsing.
    def initialize(response, selectors:, time_zone:)
      @response = response
      @url = response.url
      @selectors = selectors
      @time_zone = time_zone

      prepare_selectors!
      @rss_item_attributes = @selectors.keys & Html2rss::RssBuilder::Article::PROVIDED_KEYS
    end

    ##
    # Returns articles extracted from the response.
    # Reverses order if config specifies reverse ordering.
    #
    # @return [Array<Html2rss::RssBuilder::Article>]
    def articles
      @articles ||= @selectors.dig(ITEMS_SELECTOR_KEY, :order) == 'reverse' ? to_a.tap(&:reverse!) : to_a
    end

    ##
    # Iterates over each scraped article.
    #
    # @yield [article] Gives each article as an Html2rss::RssBuilder::Article.
    # @return [Enumerator] An enumerator if no block is given.
    def each(&)
      return enum_for(:each) unless block_given?

      enhance = enhance?

      parsed_body.css(items_selector).each do |item|
        article_hash = extract_article(item, response)

        enhance_article_hash(article_hash, item, response.url) if enhance

        yield Html2rss::RssBuilder::Article.new(**article_hash, scraper: self.class)
      end
    end

    ##
    # Returns the CSS selector for the items.
    # @return [String] the CSS selector for the items
    def items_selector = @selectors.dig(ITEMS_SELECTOR_KEY, :selector)

    ## @return [Boolean] whether to enhance the article hash with auto_source's semantic HTML extraction.
    def enhance? = !!@selectors.dig(ITEMS_SELECTOR_KEY, :enhance)

    ##
    # Extracts an article hash for a given item element.
    #
    # @param item [Nokogiri::XML::Element] The element to extract from.
    # @param page_response [RequestService::Response] response used for selector extraction context
    # @return [Hash] Hash of attributes for the article.
    def extract_article(item, page_response = response)
      @rss_item_attributes.to_h { |key| [key, select(key, item, base_url: page_response.url)] }.compact
    end

    ##
    # Enhances the article hash using semantic HTML extraction.
    # Only adds keys that are missing from the original hash.
    #
    # @param article_hash [Hash] The original article hash.
    # @param article_tag [Nokogiri::XML::Element] HTML element to extract additional info from.
    # @param base_url [String, Html2rss::Url] base URL for normalization during enhancement
    # @return [Hash] The enhanced article hash.
    def enhance_article_hash(article_hash, article_tag, base_url = @url)
      selected_anchor = HtmlExtractor.main_anchor_for(article_tag)
      return article_hash unless selected_anchor

      extracted = HtmlExtractor.new(article_tag, base_url:, selected_anchor:).call
      return article_hash unless extracted

      extracted.each_with_object(article_hash) do |(key, value), hash|
        next if value.nil? || (hash.key?(key) && hash[key])

        hash[key] = value
      end
    end

    ##
    # Selects the value for a given attribute from an HTML element.
    #
    # @param name [Symbol, String] Name of the attribute.
    # @param item [Nokogiri::XML::Element] The HTML element to process.
    # @param base_url [String, Html2rss::Url] base URL for relative extraction values
    # @return [Object, Array<Object>] The selected value(s).
    # @raise [InvalidSelectorName] If the attribute name is invalid or not defined.
    def select(name, item, base_url: @url)
      name = name.to_sym

      raise InvalidSelectorName, "Attribute selector '#{name}' is reserved for items." if name == ITEMS_SELECTOR_KEY

      selector_key, config = selector_config_for(name)

      if SPECIAL_ATTRIBUTES.member?(selector_key)
        select_special(selector_key, item:, config:, base_url:)
      else
        select_regular(selector_key, item:, config:, base_url:)
      end
    end

    private

    attr_reader :response

    def prepare_selectors!
      validate_url_and_link_exclusivity!
      fix_url_and_link!
      handle_renamed_attributes!
    end

    def validate_url_and_link_exclusivity!
      return unless @selectors.key?(:url) && @selectors.key?(:link)

      raise InvalidSelectorName, 'You must either use "url" or "link" your selectors. Using both is not supported.'
    end

    def fix_url_and_link!
      return if @selectors[:url] || !@selectors.key?(:link)

      @selectors = @selectors.dup
      @selectors[:url] = @selectors[:link]
    end

    def handle_renamed_attributes!
      RENAMED_ATTRIBUTES.each_pair do |new_name, old_names|
        old_names.each do |old_name|
          next unless @selectors.key?(old_name)

          Html2rss::Log.warn("Selector '#{old_name}' is deprecated. Please rename to '#{new_name}'.")
          @selectors[new_name] ||= @selectors.delete(old_name)
        end
      end
    end

    def parsed_body
      parsed_body_for(response)
    end

    def parsed_body_for(page_response)
      @parsed_bodies ||= {}
      @parsed_bodies[page_response.url] ||= if page_response.json_response?
                                              fragment = ObjectToXmlConverter.new(page_response.parsed_body).call
                                              Nokogiri::HTML5.fragment(fragment)
                                            else
                                              page_response.parsed_body
                                            end
    end

    def select_special(name, item:, config:, base_url:)
      case name
      when :enclosure
        enclosure(item:, config:, base_url:)
      when :guid
        Array(config).map { |selector_name| select(selector_name, item, base_url:) }
      when :categories
        select_categories(category_selectors: config, item:, base_url:)
      end
    end

    def select_regular(_name, item:, config:, base_url:)
      value = Extractors.get(config.merge(channel: channel_context(base_url)), item)

      if value && (post_process_steps = config[:post_process])
        steps = post_process_steps.is_a?(Array) ? post_process_steps : [post_process_steps]
        value = post_process(item, value, steps, base_url:)
      end

      value
    end

    def post_process(item, value, post_process_steps, base_url:)
      post_process_steps.each do |options|
        context = Context.new(config: { channel: { url: base_url, time_zone: @time_zone } },
                              item:, scraper: self, options:)

        value = PostProcessors.get(options[:name], value, context)
      end

      value
    end

    def select_categories(category_selectors:, item:, base_url:)
      Array(category_selectors).flat_map do |selector_name|
        extract_category_values(selector_name, item:, base_url:)
      end
    end

    def extract_category_values(selector_name, item:, base_url:)
      selector_key, config = selector_config_for(selector_name, allow_nil: true)
      return [] unless config

      nodes = extract_nodes(item:, config:)
      unless node_set_with_multiple_elements?(nodes)
        return Array(select_regular(selector_key, item:, config:, base_url:))
      end

      Array(nodes).flat_map { |node| extract_categories_from_node(node, item:, config:, base_url:) }
    end

    def extract_categories_from_node(node, item:, config:, base_url:)
      values = Extractors.get(category_node_options(config, base_url:), node)
      values = apply_post_process_steps(item:, value: values, post_process_steps: config[:post_process], base_url:)

      Array(values).filter_map { |category| extract_category_text(category) }
    end

    def extract_category_text(category)
      text = case category
             when Nokogiri::XML::Node, Nokogiri::XML::NodeSet
               HtmlExtractor.extract_visible_text(category)
             else
               category&.to_s
             end

      stripped = text&.strip
      stripped unless stripped.nil? || stripped.empty?
    end

    def node_set_with_multiple_elements?(nodes)
      nodes.is_a?(Nokogiri::XML::NodeSet) && nodes.length > 1
    end

    def category_node_options(selector_config, base_url:)
      selector_config.merge(channel: channel_context(base_url), selector: nil)
    end

    def apply_post_process_steps(item:, value:, post_process_steps:, base_url:)
      return value unless value && post_process_steps

      steps = post_process_steps.is_a?(Array) ? post_process_steps : [post_process_steps]
      post_process(item, value, steps, base_url:)
    end

    def selector_config_for(name, allow_nil: false)
      selector_key = name.to_sym

      return [selector_key, @selectors[selector_key]] if @selectors.key?(selector_key)
      return [selector_key, nil] if allow_nil

      raise InvalidSelectorName, "Selector for '#{selector_key}' is not defined."
    end

    def extract_nodes(item:, config:)
      return unless config.respond_to?(:[]) && config[:selector]

      Extractors.element(item, config[:selector])
    end

    def channel_context(base_url)
      { url: base_url, time_zone: @time_zone }
    end

    # @return [Hash] enclosure details.
    def enclosure(item:, config:, base_url:)
      url = Url.from_relative(select_regular(:enclosure, item:, config:, base_url:), base_url)

      { url:, type: config[:content_type] }
    end
  end
end
