# frozen_string_literal: true

module Html2rss
  class HtmlExtractor
    # Extracts the earliest date from an article_tag.
    class DateExtractor
      # @param article_tag [Nokogiri::XML::Element] article container node
      # @return [DateTime, nil]
      def self.call(article_tag)
        times = article_tag.css('[datetime]').filter_map do |tag|
          DateTime.parse(tag['datetime'])
        rescue ArgumentError, TypeError
          nil
        end

        times.min
      end
    end
  end
end
