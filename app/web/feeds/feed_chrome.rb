# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Instance-wide RSS chrome: stylesheets and outbound User-Agent.
      #
      # Previously loaded from +config/feeds.yml+ global keys; now owned here so
      # boot and token feed generation share one source.
      module FeedChrome
        STYLESHEETS = [
          { href: '/rss.xsl', media: 'all', type: 'text/xsl' }.freeze
        ].freeze

        HEADERS = {
          'User-Agent' =>
            'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) ' \
            'Chrome/108.0.0.0 Safari/537.36'
        }.freeze

        class << self
          ##
          # @return [Array<Hash{Symbol => String}>]
          def stylesheets
            STYLESHEETS
          end

          ##
          # @return [Hash{String => String}]
          def headers
            HEADERS
          end

          ##
          # Slice used by token feed generator input.
          #
          # @return [Hash{Symbol => Object}]
          def generator_defaults
            { stylesheets:, headers: }
          end
        end
      end
    end
  end
end
