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
              cacheable: ->(result) { result.status != :error }
            ) do
              build_result(resolved_source, cache_key)
            end
          end

          private

          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def build_result(resolved_source, cache_key)
            feed_result = Html2rss.feed_result(resolved_source.generator_input)
            success_result(feed_result, resolved_source, cache_key)
          rescue StandardError => error
            decision = ErrorClassifier.classify(error)
            diagnostics = ErrorClassifier::Diagnostics.from_error(error)
            if decision.cacheable
              return classified_empty_result(error, decision, diagnostics, resolved_source, cache_key)
            end

            error_result(error, decision, diagnostics, resolved_source, cache_key)
          end

          # @param feed_result [Html2rss::FeedResult]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def success_result(feed_result, resolved_source, cache_key)
            return empty_feed_result(feed_result, resolved_source, cache_key) if feed_result.empty?

            render_result(
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
            render_result(
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
          def classified_empty_result(error, decision, diagnostics, resolved_source, cache_key)
            render_result(
              status: :empty,
              decision:,
              diagnostics:,
              payload: payload_for(resolved_source),
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key:,
              error_message: error.message,
              empty_reason: 'content_extraction_empty'
            )
          end

          # @param error [StandardError]
          # @param decision [Html2rss::Web::ErrorClassifier::Decision]
          # @param diagnostics [Html2rss::Web::ErrorClassifier::Diagnostics]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def error_result(error, decision, diagnostics, resolved_source, cache_key)
            render_result(
              status: :error,
              decision:,
              diagnostics:,
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key:,
              error_message: error.message
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

          # @param attrs [Hash{Symbol=>Object}]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def render_result(**attrs)
            Contracts::RenderResult.new(
              payload: nil,
              error_message: nil,
              empty_reason: nil,
              **attrs
            )
          end
        end
      end
    end
  end
end
