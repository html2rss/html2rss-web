# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Single owner of token-feed config expansion, so a preview can never diverge
      # from the feed a reader later receives.
      module GeneratorInput
        SUPPORTED_STRATEGIES = Set.new(Html2rss::RequestService.strategy_names.map(&:to_s)).freeze
        private_constant :SUPPORTED_STRATEGIES

        class << self
          ##
          # Builds the generator config for a signed token feed.
          #
          # Without +selectors+ the config keeps +auto_source+. With them, the signed
          # selectors replace it, so the gem does not also run the general scrapers.
          #
          # @param url [String] channel URL bound to the token
          # @param strategy [String, nil] token strategy; nil or blank resolves to the default
          # @param selectors [Hash{Symbol=>Object}, nil] validated selectors, see {SelectorsDocument.parse}
          # @return [Hash{Symbol=>Object}]
          # @raise [Html2rss::Web::BadRequestError] when the strategy is unsupported
          def for_token(url:, strategy: nil, selectors: nil)
            expanded = LocalConfig.global.slice(:stylesheets, :headers).merge(
              channel: { url: },
              strategy: resolve_strategy(strategy).to_sym
            )
            selectors ? expanded.merge(selectors:) : expanded.merge(auto_source: {})
          end

          private

          # @param strategy [String, nil]
          # @return [String]
          def resolve_strategy(strategy)
            name = strategy.to_s.strip
            return default_strategy_name if name.empty? || name == default_strategy_name
            raise BadRequestError, 'Unsupported strategy' unless SUPPORTED_STRATEGIES.include?(name)

            name
          end

          # @return [String]
          def default_strategy_name
            configured = Html2rss::Config.default_strategy_name.to_s
            configured.strip.empty? ? 'auto' : configured
          end
        end
      end
    end
  end
end
