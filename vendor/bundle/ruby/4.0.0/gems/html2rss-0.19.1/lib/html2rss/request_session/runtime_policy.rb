# frozen_string_literal: true

module Html2rss
  class RequestSession
    ##
    # Builds the runtime request policy for a feed run.
    class RuntimePolicy
      ##
      # @param config [Html2rss::Config] validated feed config
      # @return [Html2rss::RequestService::Policy] request policy derived from runtime config
      def self.from_config(config)
        RequestService::Policy.new(
          max_requests: effective_max_requests_for(config),
          max_redirects: config.max_redirects
        )
      end

      class << self
        private

        def effective_max_requests_for(config)
          return config.max_requests if config.explicit_max_requests?

          [baseline_request_budget_for(config), config.max_requests].max
        end

        # Reserve enough budget for the initial request plus predictable follow-ups
        # that the top-level pipeline may trigger during a normal feed build.
        def baseline_request_budget_for(config)
          1 + pagination_follow_up_budget_for(config) +
            known_auto_source_follow_up_budget_for(config) +
            auto_strategy_fallback_budget_for(config) +
            browserless_preload_budget_for(config)
        end

        def auto_strategy_fallback_budget_for(config)
          return 0 unless config.strategy == :auto

          [FeedPipeline::AutoFallback::CHAIN.size - 1, 0].max
        end

        def pagination_follow_up_budget_for(config)
          [config.selectors&.dig(:items, :pagination, :max_pages).to_i - 1, 0].max
        end

        def known_auto_source_follow_up_budget_for(config)
          config.auto_source&.dig(:scraper, :wordpress_api, :enabled) ? 1 : 0
        end

        def browserless_preload_budget_for(config)
          preload = config.request.dig(:browserless, :preload)
          return 0 unless preload

          top_level_preload_wait_budget(preload) +
            click_selector_preload_budget(preload) +
            scroll_preload_budget(preload)
        end

        def top_level_preload_wait_budget(preload)
          preload[:wait_after_ms] ? 2 : 0
        end

        def click_selector_preload_budget(preload)
          preload.fetch(:click_selectors, []).sum { preload_action_budget(_1, :max_clicks) }
        end

        def scroll_preload_budget(preload)
          scroll = preload[:scroll_down]
          return 0 unless scroll

          preload_action_budget(scroll, :iterations)
        end

        def preload_action_budget(config, count_key)
          action_count = config.fetch(count_key, 1)
          wait_budget = config[:wait_after_ms] ? action_count : 0

          action_count + wait_budget
        end
      end
    end
  end
end
