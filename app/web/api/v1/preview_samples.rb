# frozen_string_literal: true

require 'nokogiri'
require 'rss'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Maps a preview extraction into meadow rows.
        #
        # Gem samples stay at three items. The authenticated meadow cap is {SAMPLE_LIMIT}
        # (the same 10 the member JSON Feed preview uses in
        # frontend/src/feeds/feedParsers.ts as PREVIEW_ITEM_LIMIT.member).
        # Rows use {SAMPLE_KEYS}. An unusable RSS document keeps the gem samples.
        module PreviewSamples
          SAMPLE_LIMIT = 10
          SAMPLE_KEYS = %w[title url published_at image].freeze

          class << self
            ##
            # RSS items when the document parsed; otherwise the gem samples.
            #
            # @param result [Html2rss::Test::Result]
            # @return [Array<Hash>]
            def from_result(result)
              from_rss = samples_from_rss(result.rss)
              return from_rss unless from_rss.nil?

              result.sample_items
            end

            private

            # @param rss [String, nil]
            # @return [Array<Hash>, nil] nil asks the caller to keep gem samples
            def samples_from_rss(rss)
              return unless rss.is_a?(String) && !rss.strip.empty?

              items = RSS::Parser.parse(rss, false)&.items.to_a
              return if items.empty?

              items.first(SAMPLE_LIMIT).map { sample_from_item(it) }
            rescue RSS::Error
              nil
            end

            # @param item [RSS::Rss::Channel::Item]
            # @return [Hash]
            def sample_from_item(item)
              sample = {
                'title' => item.title.to_s.strip,
                'url' => item_link(item),
                'published_at' => published_at(item)
              }
              image = description_image_src(item) || image_enclosure_url(item)
              image ? sample.merge('image' => image) : sample
            end

            # @param item [RSS::Rss::Channel::Item]
            # @return [String]
            def item_link(item)
              link = item.link if item.respond_to?(:link)
              link = item.url if link.to_s.strip.empty? && item.respond_to?(:url)
              link.to_s.strip
            end

            # @param item [RSS::Rss::Channel::Item]
            # @return [String, nil]
            def published_at(item)
              value = item.pubDate if item.respond_to?(:pubDate)
              return if value.nil?
              return value.utc.iso8601 if value.respond_to?(:utc)

              text = value.to_s.strip
              text.empty? ? nil : text
            end

            # First http(s) +<img src>+ in the item description. Article images are prepended there.
            #
            # @param item [RSS::Rss::Channel::Item]
            # @return [String, nil]
            def description_image_src(item)
              html = item.description.to_s if item.respond_to?(:description)
              return if html.nil? || html.empty?

              node = Nokogiri::HTML.fragment(html).css('img').find { http_image_url(it['src']) }
              http_image_url(node['src']) if node
            end

            # Image +enclosure+ only. Audio and other types are not preview images.
            #
            # @param item [RSS::Rss::Channel::Item]
            # @return [String, nil]
            def image_enclosure_url(item)
              return unless item.respond_to?(:enclosure)

              enclosure = item.enclosure
              type = enclosure.respond_to?(:type) ? enclosure.type.to_s : ''
              return unless type.downcase.start_with?('image/')

              http_image_url(enclosure.url)
            end

            # @param value [String, nil]
            # @return [String, nil]
            def http_image_url(value)
              url = value.to_s.strip
              return unless url.start_with?('https://', 'http://')
              return if url.match?(/[[:space:]"'<>]/)

              url
            end
          end
        end
      end
    end
  end
end
