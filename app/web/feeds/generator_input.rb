# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Single owner of token-feed config expansion.
      #
      # Serve and studio preview both call {.for_token} so a preview cannot
      # diverge from the feed a reader later receives.
      module GeneratorInput
        SUPPORTED_STRATEGIES = Set.new(Html2rss::RequestService.strategy_names.map(&:to_s)).freeze
        private_constant :SUPPORTED_STRATEGIES

        class << self
          ##
          # Builds the generator config for a signed token feed.
          #
          # A nil or blank +strategy+ resolves to the configured default, or +auto+
          # when that default is blank. An explicit name must be supported.
          #
          # @param url [String] channel URL bound to the token
          # @param strategy [String, Symbol, nil] token strategy, or nil for the configured default
          # @param selectors [Html2rss::Web::SelectorsDocument, nil] signed selector fragment
          # @return [Hash{Symbol=>Object}]
          def for_token(url:, strategy: nil, selectors: nil)
            expanded = LocalConfig.global.slice(:stylesheets, :headers).merge(
              channel: { url: },
              auto_source: {},
              strategy: resolve_strategy(strategy).to_sym
            )
            return expanded if selectors.nil? || selectors.empty?

            expanded.merge(selectors.to_config_fragment)
          end

          private

          # @param strategy [String, Symbol, nil]
          # @return [String]
          # @raise [Html2rss::Web::BadRequestError] when the name is not supported
          def resolve_strategy(strategy)
            name = strategy.to_s.strip
            return default_strategy_name if name.empty?
            return name if name == default_strategy_name
            raise Html2rss::Web::BadRequestError, 'Unsupported strategy' unless SUPPORTED_STRATEGIES.include?(name)

            name
          end

          # @return [String]
          def default_strategy_name
            configured = Html2rss::Config.default_strategy_name.to_s
            return configured unless configured.strip.empty?

            'auto'
          end
        end
      end
    end
  end
end
