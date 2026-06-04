# frozen_string_literal: true

require 'rss'

module Html2rss
  ##
  # Builds an RSS Feed by providing channel, articles and stylesheets.
  class RssBuilder
    class << self
      # @param article [Html2rss::RssBuilder::Article] source article
      # @param item_maker [RSS::Maker::RSS20::ItemsBase::ItemBase] RSS item builder
      # @return [void]
      def add_item(article, item_maker)
        add_item_string_values(article, item_maker)
        add_item_categories(article, item_maker)
        Enclosure.add(article.enclosure, item_maker)
        add_item_guid(article, item_maker)
      end

      private

      def add_item_string_values(article, item_maker)
        %i[title description author].each do |attr|
          next unless (value = article.send(attr))
          next if value.empty?

          item_maker.send(:"#{attr}=", value)
        end

        item_maker.link = article.url.to_s if article.url
        item_maker.pubDate = article.published_at&.rfc2822
      end

      def add_item_categories(article, item_maker)
        article.categories.each { |category| item_maker.categories.new_category.content = category }
      end

      def add_item_guid(article, item_maker)
        item_maker.guid.tap do |guid|
          guid.content = article.guid
          guid.isPermaLink = false
        end
      end
    end

    ##
    # @param channel [Html2rss::RssBuilder::Channel] The channel information for the RSS feed.
    # @param articles [Array<Html2rss::RssBuilder::Article>] The list of articles to include in the RSS feed.
    # @param stylesheets [Array<Hash>] An optional array of stylesheet configurations.
    def initialize(channel:, articles:, stylesheets: [])
      @channel = channel
      @articles = articles
      @stylesheets = stylesheets
    end

    # @return [RSS::Rss] RSS 2.0 document instance
    def call
      RSS::Maker.make('2.0') do |maker|
        Stylesheet.add(maker, stylesheets)

        make_channel(maker.channel)
        make_items(maker)
      end
    end

    private

    attr_reader :channel, :articles

    def stylesheets
      @stylesheets.map { |style| Stylesheet.new(**style) }
    end

    def make_channel(maker)
      %i[language title description ttl].each do |key|
        maker.public_send(:"#{key}=", channel.public_send(key))
      end

      maker.link = channel.url.to_s
      maker.generator = generator
      maker.updated = channel.last_build_date
    end

    def make_items(maker)
      articles.each do |article|
        maker.items.new_item { |item_maker| self.class.add_item(article, item_maker) }
      end
    end

    def generator
      scraper_namespace_regex = /(?<namespace>Html2rss|Scraper)::/

      scraper_counts = articles.flat_map(&:scraper).tally.map do |klass, count|
        scraper_name = klass.to_s.gsub(scraper_namespace_regex, '')
        "#{scraper_name} (#{count})"
      end

      "html2rss V. #{Html2rss::VERSION} (scrapers: #{scraper_counts.join(', ')})"
    end
  end
end
