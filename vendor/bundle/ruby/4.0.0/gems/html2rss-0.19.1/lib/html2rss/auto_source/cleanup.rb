# frozen_string_literal: true

module Html2rss
  class AutoSource
    ##
    # Cleanup is responsible for cleaning up the extracted articles.
    # :reek:MissingSafeMethod { enabled: false }
    # It applies various strategies to filter and refine the article list.
    class Cleanup
      # Default cleanup behavior for auto-sourced article lists.
      DEFAULT_CONFIG = {
        keep_different_domain: false,
        min_words_title: 3
      }.freeze

      # Allowed URL schemes for article filtering.
      VALID_SCHEMES = %w[http https].to_set.freeze

      class << self
        # @param articles [Array<Article>] extracted article candidates
        # @param url [Html2rss::Url] feed source URL used for same-host filtering
        # @param keep_different_domain [Boolean] whether to keep off-domain entries
        # @param min_words_title [Integer] minimum word count for title filtering
        # @return [Array<Article>] cleaned article list
        def call(articles, url:, keep_different_domain:, min_words_title:)
          Log.debug "Cleanup: start with #{articles.size} articles"

          articles.select!(&:valid?)

          deduplicate_by!(articles, :url)

          keep_only_http_urls!(articles)
          reject_different_domain!(articles, url) unless keep_different_domain
          keep_only_with_min_words_title!(articles, min_words_title:)

          Log.debug "Cleanup: end with #{articles.size} articles"
          articles
        end

        ##
        # Deduplicates articles by a given key.
        #
        # @param articles [Array<Article>] The list of articles to process.
        # @param key [Symbol] The key to deduplicate by.
        # @return [Array<Article>] the mutated articles array
        def deduplicate_by!(articles, key)
          seen = {}
          articles.reject! do |article|
            value = article.public_send(key)
            value.nil? || seen.key?(value).tap { seen[value] = true }
          end
        end

        ##
        # Keeps only articles with HTTP or HTTPS URLs.
        #
        # @param articles [Array<Article>] The list of articles to process.
        # @return [Array<Article>] the mutated articles array
        def keep_only_http_urls!(articles)
          articles.select! { |article| VALID_SCHEMES.include?(article.url&.scheme) }
        end

        ##
        # Rejects articles that have a URL not on the same domain as the source.
        #
        # @param articles [Array<Article>] The list of articles to process.
        # @param base_url [Html2rss::Url] The source URL to compare against.
        # @return [Array<Article>] the mutated articles array
        def reject_different_domain!(articles, base_url)
          base_host = base_url.host
          articles.select! { |article| article.url&.host == base_host }
        end

        ##
        # Keeps only articles with a title that is present and has at least `min_words_title` words.
        #
        # @param articles [Array<Article>] The list of articles to process.
        # @param min_words_title [Integer] The minimum number of words in the title.
        # @return [Array<Article>] the mutated articles array
        def keep_only_with_min_words_title!(articles, min_words_title:)
          articles.select! do |article|
            article.title ? word_count_at_least?(article.title, min_words_title) : true
          end
        end

        private

        def word_count_at_least?(str, min_words)
          count = 0
          str.to_s.scan(/\p{Alnum}+/) do
            count += 1
            return true if count >= min_words
          end
          false
        end
      end
    end
  end
end
