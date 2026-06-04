# frozen_string_literal: true

module Html2rss
  ##
  # Builds feeds from validated config through request, extraction, and rendering stages.
  class FeedPipeline
    ##
    # @param raw_config [Hash{Symbol => Object}] user-provided feed config
    def initialize(raw_config)
      @raw_config = raw_config
    end

    ##
    # @return [RSS::Rss] generated RSS feed
    def to_rss
      run do |response:, config:, articles:|
        channel = RssBuilder::Channel.new(response, overrides: config.channel)
        RssBuilder.new(channel:, articles:, stylesheets: config.stylesheets).call
      end
    end

    ##
    # @return [Hash] generated JSONFeed 1.1 payload
    def to_json_feed
      run do |response:, config:, articles:|
        channel = RssBuilder::Channel.new(response, overrides: config.channel)
        JsonFeedBuilder.new(channel:, articles:).call
      end
    end

    private

    attr_reader :raw_config

    def run
      config = Config.from_hash(raw_config, params: raw_config[:params])
      state = pipeline_state_for(config)
      yield response: state.fetch(:response), config:, articles: state.fetch(:articles)
    end

    def pipeline_state_for(config)
      if config.strategy == :auto
        run_auto_pipeline(config)
      else
        run_pipeline_for_strategy(config, strategy: config.strategy)
      end
    end

    def run_pipeline_for_strategy(config, strategy:, budget: nil)
      request_session = request_session_for(config, strategy:, budget:)
      response = request_session.fetch_initial_response
      articles = deduplicated_articles(response:, config:, request_session:)
      { response:, articles: }
    end

    def request_session_for(config, strategy:, budget: nil)
      RequestSession.from_runtime_input(runtime_input_for(config, strategy:), budget:)
    end

    def runtime_input_for(config, strategy:)
      RequestSession::RuntimeInput.new(
        url: config.url,
        headers: config.headers,
        request: config.request,
        strategy:,
        request_policy: RequestSession::RuntimePolicy.from_config(config)
      )
    end

    def deduplicated_articles(response:, config:, request_session:)
      Articles::Deduplicator.new(
        collect_articles(response:, config:, request_session:)
      ).call
    end

    def run_auto_pipeline(config)
      auto_fallback_for(config).call
    end

    def auto_fallback_for(config)
      AutoFallback.new(
        strategies: AutoFallback::CHAIN,
        budget: auto_pipeline_budget(config),
        session_for: lambda do |strategy:, budget:|
          request_session_for(config, strategy:, budget:)
        end,
        articles_for: lambda do |response:, request_session:|
          deduplicated_articles(response:, config:, request_session:)
        end
      )
    end

    def auto_pipeline_budget(config)
      max_requests = RequestSession::RuntimePolicy.from_config(config).max_requests
      RequestService::Budget.new(max_requests:)
    end

    def collect_articles(response:, config:, request_session:)
      selector_articles(response:, config:, request_session:) +
        auto_source_articles(response:, config:, request_session:)
    end

    def selector_articles(response:, config:, request_session:) # rubocop:disable Metrics/MethodLength
      return [] unless (selectors = config.selectors)

      page_responses = if (max_pages = selectors.dig(:items, :pagination, :max_pages))
                         RequestSession::RelNextPager.new(
                           session: request_session,
                           initial_response: response,
                           max_pages:
                         ).to_a
                       else
                         [response]
                       end

      page_responses.flat_map do |page_response|
        Selectors.new(page_response, selectors:, time_zone: config.time_zone).articles
      end
    end

    def auto_source_articles(response:, config:, request_session:)
      return [] unless (auto_source = config.auto_source)

      AutoSource.new(response, auto_source, request_session:).articles
    end
  end
end
