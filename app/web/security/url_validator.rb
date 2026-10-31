# frozen_string_literal: true

require 'html2rss/url'

module Html2rss
  module Web
    ##
    # URL validation and pattern matching utilities built on Html2rss::Url
    module UrlValidator
      MAX_URL_LENGTH = 2048

      class << self
        # @param url [String]
        # @return [String, nil]
        def canonical_url(url)
          normalize_url(url)
        end

        # @param url [String]
        # @return [Boolean]
        def valid_url?(url)
          !canonical_url(url).nil?
        end

        # @param account [Hash]
        # @param url [String]
        # @return [Boolean]
        def url_allowed?(account, url)
          return false unless account
          return false unless (normalized_url = canonical_url(url))

          Array(account[:allowed_urls]).any? do |pattern|
            wildcard?(pattern) ? match_wildcard?(pattern, normalized_url) : match_exact?(pattern, normalized_url)
          end
        end

        private

        def match_exact?(pattern, normalized_url)
          canonical_url(pattern) == normalized_url
        end

        def match_wildcard?(pattern, normalized_url)
          File.fnmatch?(pattern, normalized_url, File::FNM_CASEFOLD)
        end

        def wildcard?(pattern)
          pattern.include?('*')
        end

        # mutant:disable - `Url` resolves to the same constant lexically; the mutation is equivalent.
        def normalize_url(url)
          return nil unless url.is_a?(String) && !url.empty? && url.length <= MAX_URL_LENGTH

          Html2rss::Url.for_channel(url).to_s
        rescue StandardError
          nil
        end
      end
    end
  end
end
