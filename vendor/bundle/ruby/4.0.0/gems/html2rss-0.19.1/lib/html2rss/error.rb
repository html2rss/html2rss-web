# frozen_string_literal: true

module Html2rss
  # The Html2rss::Error base class.
  class Error < StandardError; end

  # Raised when auto fallback exhausts all concrete tiers and extractors find no feed items.
  class NoFeedItemsExtracted < Error
    ##
    # @param attempts [Array<Hash{Symbol => Object}>] tier attempt diagnostics
    def initialize(attempts:)
      @attempts = attempts
      super(build_message)
    end

    # @return [Array<Hash{Symbol => Object}>] tier attempt diagnostics
    attr_reader :attempts

    private

    def build_message
      summaries = attempts.map do |attempt|
        details = attempt[:items_count].nil? ? "#{attempt[:error_class]} error" : "#{attempt[:items_count]} items"
        "#{attempt[:strategy]} (#{details})"
      end.join(', ')

      "No feed items extracted after auto fallback across strategies: #{summaries}. " \
        'Try a more specific listing URL or provide explicit selectors.'
    end
  end
end
