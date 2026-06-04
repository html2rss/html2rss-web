# frozen_string_literal: true

require 'json'

module Html2rss
  class AutoSource
    module Scraper
      ##
      # Scrapes JSON state blobs embedded in script tags such as Next.js, Nuxt,
      # or custom window globals. The scraper searches `<script type="application/json">`
      # tags and well-known JavaScript globals for arrays of article-like hashes
      # and normalises them to a structure compatible with HtmlExtractor.
      class JsonState
        include Enumerable

        # Selector for JSON-only script tags.
        JSON_SCRIPT_SELECTOR = 'script[type="application/json"]'
        # Regex patterns for known global JavaScript state assignments.
        GLOBAL_ASSIGNMENT_PATTERNS = [
          /(?:window|self|globalThis)\.__NEXT_DATA__\s*=\s*/m,
          /(?:window|self|globalThis)\.__NUXT__\s*=\s*/m,
          /(?:window|self|globalThis)\.STATE\s*=\s*/m,
          /(?:window|self|globalThis)\.__REDUX_STATE__\s*=\s*/m,
          /(?:window|self|globalThis)\.__PRELOADED_STATE__\s*=\s*/m,
          /(?:window|self|globalThis)\.__APOLLO_STATE__\s*=\s*/m,
          /(?:window|self|globalThis)\.__remixContext\s*=\s*/m,
          /(?:window|self|globalThis)\.__sveltekit_data\s*=\s*/m,
          /(?:window|self|globalThis)\.GATSBY_STATE\s*=\s*/m,
          /(?:window|self|globalThis)\.__ember_meta\s*=\s*/m,
          /(?:window|self|globalThis)\.angular\s*=\s*/m
        ].freeze

        # Preferred keys when extracting title-like values from state payloads.
        TITLE_KEYS = %i[title headline name text].freeze
        # Preferred keys when extracting URL-like values from state payloads.
        URL_KEYS = %i[url link href permalink slug path canonicalUrl shortUrl].freeze
        # Preferred keys when extracting description-like values from state payloads.
        DESCRIPTION_KEYS = %i[description summary excerpt dek subheading].freeze
        # Preferred keys when extracting image-like values from state payloads.
        IMAGE_KEYS = %i[image imageUrl thumbnailUrl thumbnail src featuredImage coverImage heroImage].freeze
        # Preferred keys when extracting publication timestamps from state payloads.
        PUBLISHED_AT_KEYS = %i[published_at publishedAt datePublished date publicationDate pubDate updatedAt updated_at
                               createdAt created_at].freeze
        # Preferred keys when extracting category-like values from state payloads.
        CATEGORY_KEYS = %i[categories tags section sections topic topics channel].freeze
        # Preferred keys when extracting identifier-like values from state payloads.
        ID_KEYS = %i[id guid uuid slug key].freeze

        # Scans DOM nodes for JSON payloads containing article data.
        module DocumentScanner
          module_function

          # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
          # @return [Array<Hash, Array>] parsed JSON documents discovered in scripts
          def json_documents(parsed_body)
            script_documents(parsed_body) + assignment_documents(parsed_body)
          end

          # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
          # @return [Array<Hash, Array>] JSON documents extracted from JSON script tags
          def script_documents(parsed_body)
            parsed_body.css(JSON_SCRIPT_SELECTOR).filter_map { parse_json(_1.text) }
          end

          # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
          # @return [Array<Hash, Array>] JSON documents extracted from global assignments
          def assignment_documents(parsed_body)
            parsed_body.css('script').filter_map { parse_assignment(_1.text) }
          end

          # @param text [String] script text that may contain a global assignment
          # @return [Hash, Array, nil] parsed assignment payload when available
          def parse_assignment(text)
            payload = assignment_payload(text)
            parse_json(payload) if payload
          end

          # @param text [String] script text to inspect for known assignment patterns
          # @return [String, nil] extracted JSON-like assignment payload
          def assignment_payload(text)
            trimmed = text.to_s.strip
            return if trimmed.empty?

            GLOBAL_ASSIGNMENT_PATTERNS.each do |pattern|
              next unless trimmed.match?(pattern)

              payload = trimmed.sub(pattern, '')
              return extract_assignment_payload(payload)
            end

            nil
          end

          # @param text [String] text potentially containing JSON-like payloads
          # @return [String, nil] normalized assignment payload
          def extract_assignment_payload(text)
            extract_json_block(text) || text
          end

          # @param text [String] text potentially containing JSON blocks
          # @return [String, nil] extracted JSON block spanning balanced brackets
          def extract_json_block(text)
            start_index = text.index(/[\[{]/)
            return unless start_index

            stop_index = scan_for_json_end(text, start_index)
            text[start_index..stop_index] if stop_index
          end

          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          # @param text [String] text starting with a JSON object/array opening token
          # @param start_index [Integer] index where JSON-like content starts
          # @return [Integer, nil] index where the balanced JSON payload ends
          def scan_for_json_end(text, start_index)
            stack = []
            in_string = false
            escape = false

            text.each_char.with_index do |char, index|
              next if index < start_index

              if in_string
                if escape
                  escape = false
                elsif char == '\\'
                  escape = true
                elsif char == '"'
                  in_string = false
                end
                next
              end

              case char
              when '"'
                in_string = true
              when '{'
                stack << '}'
              when '['
                stack << ']'
              when '}', ']'
                expected = stack.pop
                return index if expected == char && stack.empty?
              end
            end

            nil
          end
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

          # @param payload [String, nil] JSON payload to parse
          # @return [Hash, Array, nil] parsed payload or nil when parsing fails
          def parse_json(payload)
            return unless payload

            JSON.parse(payload, symbolize_names: true)
          rescue JSON::ParserError => error
            parse_js_object(payload, error)
          end

          # @param payload [String] JavaScript object-literal payload
          # @param _original_error [JSON::ParserError] original JSON parse error
          # @return [Hash, Array, nil] parsed payload after JavaScript coercion
          def parse_js_object(payload, _original_error)
            coerced = coerce_javascript_object(payload)
            return unless coerced

            # Some sites emit JavaScript object literals (unquoted keys, trailing commas).
            # Coerce those payloads into valid JSON so we keep the same parsing pipeline.
            JSON.parse(coerced, symbolize_names: true)
          rescue JSON::ParserError => error
            Html2rss::Log.debug("#{name}: failed to parse coerced JavaScript object (#{error.message})")
            nil
          end

          # @param payload [String] JavaScript object-literal payload
          # @return [String] JSON-compatible payload string
          def coerce_javascript_object(payload)
            string = payload.dup

            # KISS approach: mutate common JS literal quirks instead of a full parser.
            strip_trailing_commas(quote_unquoted_keys(string))
          end

          # @param jsonish [String] JSON-like string with potentially unquoted keys
          # @return [String] payload with unquoted object keys quoted
          def quote_unquoted_keys(jsonish)
            jsonish.gsub(/(\A\s*|[{,\[]\s*)([A-Za-z_]\w*)(\s*:)/) do
              "#{Regexp.last_match(1)}\"#{Regexp.last_match(2)}\"#{Regexp.last_match(3)}"
            end
          end

          # @param jsonish [String] JSON-like string with potential trailing commas
          # @return [String] payload without trailing commas before closing tokens
          def strip_trailing_commas(jsonish)
            jsonish.gsub(/,(\s*[\]}])/, '\1')
          end
        end
        private_constant :DocumentScanner

        # Retrieves values from heterogeneous objects by probing multiple keys.
        module ValueFinder
          module_function

          # @param object [Hash, Array] candidate container traversed during key lookup
          # @param keys [Array<Symbol>] keys to probe in order
          # @return [Object, nil] first matching value
          def fetch(object, keys)
            case object
            when Hash then fetch_from_hash(object, keys)
            when Array then fetch_from_array(object, keys)
            end
          end

          # @param hash [Hash] hash candidate traversed during key lookup
          # @param keys [Array<Symbol>] keys to probe in order
          # @return [Object, nil] first matching value from hash or nested metadata
          def fetch_from_hash(hash, keys)
            keys.each do |key|
              return hash[key] if hash.key?(key)
            end

            fetch_nested(hash[:attributes], keys) ||
              fetch_nested(hash[:data], keys)
          end

          # @param array [Array] array whose entries may contain target keys
          # @param keys [Array<Symbol>] keys to probe in order
          # @return [Object, nil] first matching value from array entries
          def fetch_from_array(array, keys)
            array.each do |entry|
              result = fetch(entry, keys)
              return result if result
            end

            nil
          end

          # @param value [Hash, Array, nil] nested value to recurse into
          # @param keys [Array<Symbol>] keys to probe in order
          # @return [Object, nil] matching nested value
          def fetch_nested(value, keys)
            fetch(value, keys) if value
          end
        end
        private_constant :ValueFinder

        # Identifies arrays that look like collections of article hashes.
        module CandidateDetector
          module_function

          # @param document [Hash, Array, Object] candidate document node
          # @return [Boolean] whether the node contains article-like arrays
          def candidate_array?(document)
            case document
            when Array
              return true if array_of_articles?(document)

              document.any? { traversable_candidate?(_1) }
            when Hash then document.each_value.any? { candidate_array?(_1) }
            else false
            end
          end

          # @param value [Hash, Array, Object] candidate nested value
          # @return [Boolean] whether nested value should be traversed for article candidates
          def traversable_candidate?(value)
            case value
            when Array, Hash then candidate_array?(value)
            else false
            end
          end

          # @param array [Array<Object>] candidate list of entries
          # @return [Boolean] whether array includes hash entries with title and URL fields
          def array_of_articles?(array)
            array.any? do |element|
              next unless element.is_a?(Hash)

              title_from(element) && url_from(element)
            end
          end

          # @param object [Hash] article candidate object
          # @return [Object, nil] detected title-like value
          def title_from(object)
            ValueFinder.fetch(object, TITLE_KEYS)
          end

          # @param object [Hash] article candidate object
          # @return [Object, nil] detected URL-like value
          def url_from(object)
            ValueFinder.fetch(object, URL_KEYS)
          end
        end
        private_constant :CandidateDetector

        # Shapes raw entries into the structure required downstream.
        module ArticleNormalizer
          module_function

          # rubocop:disable Metrics/MethodLength
          # @param entry [Hash] raw article entry candidate
          # @param base_url [String, Html2rss::Url] base URL for relative link resolution
          # @return [Hash{Symbol => Object}, nil] normalized article hash for downstream extraction
          def normalise(entry, base_url:)
            return unless entry.is_a?(Hash)

            title = string(ValueFinder.fetch(entry, TITLE_KEYS))
            description = string(ValueFinder.fetch(entry, DESCRIPTION_KEYS))
            article_url = resolve_link(entry, keys: URL_KEYS, base_url:,
                                              log_key: 'JsonState: invalid URL encountered')
            return unless article_url
            return if title.nil? && description.nil?

            {
              title:,
              description:,
              url: article_url,
              image: resolve_link(entry, keys: IMAGE_KEYS, base_url:,
                                         log_key: 'JsonState: invalid image URL encountered'),
              published_at: string(ValueFinder.fetch(entry, PUBLISHED_AT_KEYS)),
              categories: categories(entry),
              id: identifier(entry, article_url)
            }.compact
          end
          # rubocop:enable Metrics/MethodLength

          # @param value [Object] candidate scalar value
          # @return [String, nil] normalized non-empty string value
          def string(value)
            trimmed = value.to_s.strip
            trimmed unless trimmed.empty?
          end

          # @param entry [Hash] raw article entry candidate
          # @param keys [Array<String>] preferred link keys
          # @param base_url [String, Html2rss::Url] base URL for relative link resolution
          # @param log_key [String] structured log message key
          # @return [Html2rss::Url, nil] resolved absolute URL
          def resolve_link(entry, keys:, base_url:, log_key:)
            value = ValueFinder.fetch(entry, keys)
            value = ValueFinder.fetch(value, keys) if value.is_a?(Hash)
            string = string(value)
            return unless string

            Url.from_relative(string, base_url)
          rescue ArgumentError
            Log.debug(log_key, url: string)
            nil
          end

          # rubocop:disable Metrics/MethodLength
          # @param entry [Hash] raw article entry candidate
          # @return [Array<String>, nil] normalized unique categories
          def categories(entry)
            raw = ValueFinder.fetch(entry, CATEGORY_KEYS)
            names = case raw
                    when Array then raw
                    when Hash then raw.values
                    when String then [raw]
                    else []
                    end

            result = names.flat_map do |value|
              case value
              when Hash
                string(ValueFinder.fetch(value, %i[name title label]))
              else
                string(value)
              end
            end.compact

            result.uniq!
            result unless result.empty?
          end
          # rubocop:enable Metrics/MethodLength

          # @param entry [Hash] raw article entry candidate
          # @param article_url [Html2rss::Url] resolved article URL
          # @return [String] stable article identifier fallbacking to resolved URL
          def identifier(entry, article_url)
            value = ValueFinder.fetch(entry, ID_KEYS)
            value = ValueFinder.fetch(value, ID_KEYS) if value.is_a?(Hash)
            string(value) || article_url.to_s
          end
        end
        private_constant :ArticleNormalizer

        # @return [Symbol] scraper config key
        def self.options_key = :json_state

        class << self
          # @param parsed_body [Nokogiri::HTML::Document, nil] parsed HTML document
          def articles?(parsed_body)
            return false unless parsed_body

            DocumentScanner.json_documents(parsed_body).any? { CandidateDetector.candidate_array?(_1) }
          end

          # @param parsed_body [Nokogiri::HTML::Document, nil] parsed HTML document
          # @return [Array<Hash, Array>] parsed JSON documents discovered in the response body
          def json_documents(parsed_body)
            DocumentScanner.json_documents(parsed_body)
          end
        end

        # @param parsed_body [Nokogiri::HTML::Document, nil] parsed HTML document
        # @param url [String, Html2rss::Url] page URL used to resolve relative links
        # @param _opts [Hash] scraper-specific options
        # @option _opts [Object] :_reserved reserved for future scraper-specific options
        def initialize(parsed_body, url:, **_opts)
          @parsed_body = parsed_body
          @url = url
        end

        attr_reader :parsed_body

        # @yield [Hash{Symbol => Object}] normalized article hash
        # @return [Enumerator, void] article enumerator when no block is given
        def each
          return enum_for(:each) unless block_given?

          DocumentScanner.json_documents(parsed_body).each do |document|
            discover_articles(document) do |article|
              yield article if article
            end
          end
        end

        private

        attr_reader :url

        def discover_articles(document, &block)
          case document
          when Array then handle_array(document, &block)
          when Hash then document.each_value { discover_articles(_1, &block) if traversable?(_1) }
          end
        end

        def handle_array(array, &block)
          if CandidateDetector.array_of_articles?(array)
            array.each do |entry|
              yield(ArticleNormalizer.normalise(entry, base_url: url))
            end
          else
            array.each { discover_articles(_1, &block) if traversable?(_1) }
          end
        end

        def traversable?(value)
          value.is_a?(Array) || value.is_a?(Hash)
        end
      end
    end
  end
end
