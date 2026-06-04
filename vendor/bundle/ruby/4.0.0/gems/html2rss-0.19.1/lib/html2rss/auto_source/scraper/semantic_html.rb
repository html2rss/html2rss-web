# frozen_string_literal: true

require_relative 'semantic_html/anchor_selector'

module Html2rss
  class AutoSource
    module Scraper
      ##
      # Scrapes semantic containers by choosing one primary content link per
      # block before extraction.
      #
      # This scraper is intentionally container-first:
      # 1. collect candidate semantic containers once
      # 2. select the strongest content-like anchor within each container
      # 3. extract fields from the container while honoring that anchor choice
      #
      # The result is lower recall on weak-signal blocks, but much better link
      # quality on modern teaser cards that mix headlines, utility links, and
      # duplicate image overlays.
      class SemanticHtml
        include Enumerable

        # Container plus selected anchor chosen for extraction.
        Entry = Data.define(:container, :selected_anchor)

        # Candidate semantic container selectors used to locate extractable blocks.
        CONTAINER_SELECTORS = [
          'article:not(:has(article))',
          'section:not(:has(section))',
          'li:not(:has(li))',
          'tr:not(:has(tr))',
          'div:not(:has(div))'
        ].freeze

        ##
        # @return [Symbol] config key used to enable or configure this scraper
        def self.options_key = :semantic_html

        # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
        # @return [Boolean] true when at least one semantic container has an eligible anchor
        def self.articles?(parsed_body)
          return false unless parsed_body

          new(parsed_body, url: 'https://example.com').extractable?
        end

        # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
        # @param url [String, Html2rss::Url] base url
        # @param extractor [Class] extractor class used for article extraction
        # @param _opts [Hash] scraper-specific options
        # @option _opts [Object] :_reserved reserved for future scraper-specific options
        def initialize(parsed_body, url:, extractor: HtmlExtractor, **_opts)
          @parsed_body = parsed_body
          @url = url
          @extractor = extractor
          @anchor_selector = AnchorSelector.new(url)
        end

        attr_reader :parsed_body

        ##
        # Yields extracted article hashes for each semantic container that
        # survives anchor selection.
        #
        # Detection and extraction share the same memoized entry list so this
        # scraper does not rerun anchor ranking once a page has already been
        # accepted as extractable.
        #
        # @yieldparam article_hash [Hash] extracted article hash
        # @return [Enumerator<Hash>]
        def each
          return enum_for(:each) unless block_given?

          extractable_entries.each do |entry|
            article_hash = @extractor.new(
              entry.container,
              base_url: @url,
              selected_anchor: entry.selected_anchor
            ).call
            yield article_hash if article_hash
          end
        end

        ##
        # Reports whether the page contains at least one semantic container with
        # a selectable primary anchor.
        #
        # @return [Boolean] true when at least one candidate container yields a primary anchor
        def extractable?
          extractable_entries.any?
        end

        protected

        def candidate_containers
          @candidate_containers ||= collect_candidate_containers
        end

        def primary_anchor_for(container)
          @anchor_selector.primary_anchor_for(container)
        end

        def extractable_entries
          @extractable_entries ||= candidate_containers.filter_map do |container|
            selected_anchor = primary_anchor_for(container)
            next unless selected_anchor

            Entry.new(container:, selected_anchor:)
          end
        end

        def collect_candidate_containers
          seen = {}.compare_by_identity

          CONTAINER_SELECTORS.each_with_object([]) do |selector, containers|
            parsed_body.css(selector).each do |container|
              next if container.path.match?(Html::TAGS_TO_IGNORE)
              next if seen[container]

              seen[container] = true
              containers << container
            end
          end
        end
      end
    end
  end
end
