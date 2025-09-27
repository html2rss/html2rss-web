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
        # @return [Boolean]
        def valid_url?(url)
          !normalize_url(url).nil?
        end

        # @param account [Hash]
        # @param url [String]
        # @return [Boolean]
        def url_allowed?(account, url)
          return false unless account && url

          allowed_urls = Array(account[:allowed_urls])
          return false unless (normalized_url = normalize_url(url))

          return true if allowed_urls.empty?

          allowed_urls.any? do |pattern|
            wildcard?(pattern) ? match_wildcard?(pattern, normalized_url) : match_exact?(pattern, normalized_url)
          end
        end

        # @param url [String]
        # @param patterns [Array<String>]
        # @return [Boolean]
        def url_matches_patterns?(url, patterns)
          return false unless (normalized_url = normalize_url(url))

          Array(patterns).any? do |pattern|
            wildcard?(pattern) ? match_wildcard?(pattern, normalized_url) : match_exact?(pattern, normalized_url)
          end
        end

        # @param url [String]
        # @param pattern [String]
        # @return [Boolean]
        def url_matches_pattern?(url, pattern)
          return false unless (normalized_url = normalize_url(url))

          wildcard?(pattern) ? match_wildcard?(pattern, normalized_url) : match_exact?(pattern, normalized_url)
        end

        private

        def match_exact?(pattern, normalized_url)
          return true if pattern == normalized_url

          normalized_pattern = normalize_url(pattern)
          normalized_pattern ? normalized_pattern == normalized_url : false
        end

        def match_wildcard?(pattern, normalized_url)
          return true if pattern == '*'

          File.fnmatch?(pattern, normalized_url, File::FNM_CASEFOLD)
        end

        def wildcard?(pattern)
          pattern.include?('*')
        end

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
