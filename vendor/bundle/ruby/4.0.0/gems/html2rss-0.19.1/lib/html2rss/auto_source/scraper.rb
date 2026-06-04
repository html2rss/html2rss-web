# frozen_string_literal: true

module Html2rss
  class AutoSource
    ##
    # The Scraper module contains all scrapers that can be used to extract articles.
    # Each scraper should implement an `each` method that yields article hashes.
    # Each scraper should also implement an `articles?` method that returns true if the scraper
    # can potentially be used to extract articles from the given HTML.
    #
    # Detection is intentionally shallow for most scrapers, but instance-based
    # matching is available for scrapers that need to carry expensive selection
    # state forward into extraction.
    # Scrapers run in parallel threads, so implementations must avoid shared
    # mutable state and degrade by returning no articles when a follow-up would
    # be unsafe or unsupported.
    module Scraper
      # Root markers indicating likely app-shell/client-rendered surfaces.
      APP_SHELL_ROOT_SELECTORS = '#app, #root, #__next, [data-reactroot], [ng-app], [id*="app-shell"]'
      # Maximum anchors tolerated before app-shell detection is considered unlikely.
      APP_SHELL_MAX_ANCHORS = 2
      # Maximum visible text length tolerated for app-shell classification.
      APP_SHELL_MAX_VISIBLE_TEXT_LENGTH = 220

      # Ordered scraper classes considered during auto-source extraction.
      SCRAPERS = [
        WordpressApi,
        Schema,
        Microdata,
        JsonState,
        SemanticHtml,
        Html
      ].freeze

      ##
      # Error raised when no suitable scraper is found.
      class NoScraperFound < Html2rss::Error
        # User-facing messages grouped by no-scraper surface category.
        CATEGORY_MESSAGES = {
          blocked_surface: 'No scrapers found: blocked surface likely (anti-bot or interstitial). ' \
                           'Retry with --strategy browserless, try a more specific public listing URL, ' \
                           'or run from an environment that can complete anti-bot checks.',
          app_shell: 'No scrapers found: app-shell surface detected (client-rendered page with little or no ' \
                     'server-rendered article HTML). Retry with --strategy browserless, or target a direct ' \
                     'listing/update URL instead of a homepage or shell entrypoint.',
          unsupported_surface: 'No scrapers found: unsupported extraction surface for auto mode. ' \
                               'Try a direct listing/changelog/category URL, ' \
                               'or use explicit selectors in a feed config.'
        }.freeze

        # @param message [String, nil] custom error message override
        # @param category [Symbol] no-scraper classification
        def initialize(message = nil, category: :unsupported_surface)
          validate_category!(category)
          @category = category
          super(message || CATEGORY_MESSAGES.fetch(@category))
        end

        attr_reader :category

        private

        def validate_category!(category)
          return if CATEGORY_MESSAGES.key?(category)

          valid_categories = CATEGORY_MESSAGES.keys.join(', ')
          raise ArgumentError, "Unknown category: #{category.inspect}. Valid categories are: #{valid_categories}"
        end
      end

      ##
      # Returns an array of scraper classes that claim to find articles in the parsed body.
      # @param parsed_body [Nokogiri::HTML::Document] The parsed HTML body.
      # @param opts [Hash] The options hash.
      # @option opts [Hash] :wordpress_api scraper toggle and configuration
      # @option opts [Hash] :schema scraper toggle and configuration
      # @option opts [Hash] :microdata scraper toggle and configuration
      # @option opts [Hash] :json_state scraper toggle and configuration
      # @option opts [Hash] :semantic_html scraper toggle and configuration
      # @option opts [Hash] :html scraper toggle and configuration
      # @return [Array<Class>] An array of scraper classes that can handle the parsed body.
      def self.from(parsed_body, opts = Html2rss::AutoSource::DEFAULT_CONFIG[:scraper])
        scrapers = SCRAPERS.select { |scraper| opts.dig(scraper.options_key, :enabled) }
        scrapers.select! { |scraper| scraper.articles?(parsed_body) }

        raise no_scraper_found_for(parsed_body) if scrapers.empty?

        scrapers
      end

      # Returns scraper instances ready for extraction.
      # @param parsed_body [Nokogiri::HTML::Document] The parsed HTML body.
      # @param url [String, Html2rss::Url] The page url.
      # @param request_session [Html2rss::RequestSession, nil] Shared follow-up session.
      # @param opts [Hash] The options hash.
      # @option opts [Hash] :wordpress_api scraper toggle and configuration
      # @option opts [Hash] :schema scraper toggle and configuration
      # @option opts [Hash] :microdata scraper toggle and configuration
      # @option opts [Hash] :json_state scraper toggle and configuration
      # @option opts [Hash] :semantic_html scraper toggle and configuration
      # @option opts [Hash] :html scraper toggle and configuration
      # @return [Array<Object>] An array of scraper instances that can handle the parsed body.
      #
      # `instances_for` is the main entrypoint for extraction. It lets a scraper
      # decide whether it matches using the same instance that will later yield
      # article hashes, which keeps precomputed state close to the scraper that
      # owns it.
      def self.instances_for(parsed_body, url:, request_session: nil,
                             opts: Html2rss::AutoSource::DEFAULT_CONFIG[:scraper])
        instances = SCRAPERS.filter_map do |scraper|
          next unless opts.dig(scraper.options_key, :enabled)

          instance = scraper.new(parsed_body, url:, request_session:, **opts.fetch(scraper.options_key, {}))
          next unless extractable_instance?(instance, parsed_body)

          instance
        end

        raise no_scraper_found_for(parsed_body) if instances.empty?

        instances
      end

      def self.extractable_instance?(instance, parsed_body)
        return instance.extractable? if instance.respond_to?(:extractable?)

        instance.class.articles?(parsed_body)
      end
      private_class_method :extractable_instance?

      def self.no_scraper_found_for(parsed_body)
        NoScraperFound.new(category: classify_no_scraper_surface(parsed_body))
      end
      private_class_method :no_scraper_found_for

      def self.classify_no_scraper_surface(parsed_body)
        return :blocked_surface if blocked_surface?(parsed_body)
        return :app_shell if app_shell_surface?(parsed_body)

        :unsupported_surface
      end
      private_class_method :classify_no_scraper_surface

      def self.blocked_surface?(parsed_body)
        Html2rss::BlockedSurface.interstitial?(parsed_body.to_html)
      end
      private_class_method :blocked_surface?

      def self.app_shell_surface?(parsed_body)
        root_marker = parsed_body.at_css(APP_SHELL_ROOT_SELECTORS)
        return false unless root_marker

        sparse_anchor_surface?(parsed_body) &&
          no_article_markers?(parsed_body) &&
          short_visible_text?(parsed_body)
      end
      private_class_method :app_shell_surface?

      def self.sparse_anchor_surface?(parsed_body)
        parsed_body.css('body a[href]').size <= APP_SHELL_MAX_ANCHORS
      end
      private_class_method :sparse_anchor_surface?

      def self.no_article_markers?(parsed_body)
        parsed_body.css(
          'article, main article, [itemtype*="Article"], [itemprop="articleBody"]'
        ).empty?
      end
      private_class_method :no_article_markers?

      def self.short_visible_text?(parsed_body)
        visible_text_length(parsed_body) <= APP_SHELL_MAX_VISIBLE_TEXT_LENGTH
      end
      private_class_method :short_visible_text?

      def self.visible_text_length(parsed_body)
        body = parsed_body.at_css('body')
        return 0 unless body

        text_nodes = body.xpath('.//text()[not(ancestor::script or ancestor::style or ancestor::noscript)]')
        text_nodes.map(&:text).join(' ').gsub(/\s+/, ' ').strip.length
      end
      private_class_method :visible_text_length
    end
  end
end
