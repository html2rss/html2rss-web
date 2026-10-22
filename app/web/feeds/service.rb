# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Shared synchronous feed service around the html2rss gem.
      module Service
        class << self
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def call(resolved_source)
            cache_key = "feed_result:#{resolved_source.cache_identity}"

            Cache.fetch(
              cache_key,
              ttl_seconds: resolved_source.ttl_seconds,
              cacheable: lambda(&:cacheable?)
            ) do
              build_result(resolved_source, cache_key)
            end
          end

          private

          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def build_result(resolved_source, cache_key)
            result = scrape_result(resolved_source, cache_key)
            record_directory_last_result(resolved_source, result)
            result
          end

          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def scrape_result(resolved_source, cache_key)
            feed_result = Html2rss.feed_result(resolved_source.generator_input)
            success_result(feed_result, resolved_source, cache_key)
          rescue StandardError => error
            decision = ErrorClassifier.classify(error)
            diagnostics = ErrorClassifier::Diagnostics.from_error(error)
            # decision.status owns the body; decision.cacheable owns Cache.fetch write.
            if decision.status < 500
              return classified_empty_result(error, decision, diagnostics, resolved_source, cache_key)
            end

            error_result(error, decision, diagnostics, resolved_source, cache_key)
          end

          # Records only static scrapes whose request params match directory defaults.
          # Cache hits never reach this path (see {#call}).
          #
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def record_directory_last_result(resolved_source, result)
            return unless resolved_source.source_kind == :static
            return if resolved_source.feed_name.to_s.empty?
            return unless DirectoryParams.match?(
              resolved_source.directory_defaults,
              resolved_source.request_params
            )

            LastResults.record(resolved_source.feed_name, result)
          end

          # @param feed_result [Html2rss::FeedResult]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def success_result(feed_result, resolved_source, cache_key)
            return empty_feed_result(feed_result, resolved_source, cache_key) if feed_result.empty?

            Contracts::RenderResult.new(
              status: :ok,
              payload: payload_for(resolved_source, feed_result:),
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key:
            )
          end

          # @param feed_result [Html2rss::FeedResult]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def empty_feed_result(feed_result, resolved_source, cache_key)
            Contracts::RenderResult.new(
              status: :empty,
              decision: ErrorClassifier::EXTRACTION_EMPTY,
              payload: payload_for(resolved_source, feed_result:),
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key:,
              empty_reason: 'feed_empty'
            )
          end

          # @param error [StandardError]
          # @param decision [Html2rss::Web::ErrorClassifier::Decision]
          # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def classified_empty_result(error, decision, diagnostics, resolved_source, cache_key) # rubocop:disable Metrics/MethodLength -- empty render + reason map
            Contracts::RenderResult.new(
              status: :empty,
              decision:,
              diagnostics:,
              payload: payload_for(resolved_source),
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key:,
              error_message: error.message,
              error_class: error.class.name,
              empty_reason: decision.empty_reason
            )
          end

          # @param error [StandardError]
          # @param decision [Html2rss::Web::ErrorClassifier::Decision]
          # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def error_result(error, decision, diagnostics, resolved_source, cache_key)
            Contracts::RenderResult.new(
              status: :error,
              decision:,
              diagnostics:,
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key:,
              error_message: error.message,
              error_class: error.class.name
            )
          end

          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param feed_result [Html2rss::FeedResult, nil]
          # @return [Html2rss::Web::Feeds::Contracts::RenderPayload]
          def payload_for(resolved_source, feed_result: nil)
            Contracts::RenderPayload.new(
              feed: feed_result,
              site_title: site_title_for(resolved_source, feed_result:),
              url: resolved_source.url
            )
          end

          # Prefers gem channel title, then metadata helper, then the URL string.
          #
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param feed_result [Html2rss::FeedResult, nil]
          # @return [String]
          def site_title_for(resolved_source, feed_result: nil)
            channel_title = feed_result&.channel_title
            return channel_title unless channel_title.to_s.empty?

            url = resolved_source.url
            ChannelTitle.for(url) || url.to_s
          end
        end
      end
    end
  end
end
