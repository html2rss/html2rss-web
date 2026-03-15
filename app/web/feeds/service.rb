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
            feed = Html2rss.feed(resolved_source.generator_input)
            success_result(feed, resolved_source, cache_key)
          rescue StandardError => error
            error_result(error, resolved_source, cache_key)
          end

          # @param feed [Object]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def success_result(feed, resolved_source, cache_key)
            Contracts::RenderResult.new(
              status: result_status(feed),
              payload: payload_for(feed, resolved_source),
              message: nil,
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key: cache_key,
              error_message: nil
            )
          end

          # @param feed [Object]
          # @return [Boolean]
          def feed_has_items?(feed)
            feed.respond_to?(:items) && !feed.items.empty?
          end

          # @param feed [Object]
          # @return [Symbol]
          def result_status(feed)
            feed_has_items?(feed) ? :ok : :empty
          end

          # @param feed [Object]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @return [Html2rss::Web::Feeds::Contracts::RenderPayload]
          def payload_for(feed, resolved_source)
            Contracts::RenderPayload.new(
              feed: feed,
              site_title: site_title_for(feed, resolved_source.generator_input.dig(:channel, :url)),
              url: resolved_source.generator_input.dig(:channel, :url),
              strategy: resolved_source.generator_input[:strategy].to_s
            )
          end

          # @param feed [Object]
          # @param url [String, nil]
          # @return [String]
          def site_title_for(feed, url)
            title = feed.respond_to?(:channel) ? feed.channel&.title.to_s.strip : ''
            return title unless title.empty?

            url.to_s
          end

          # @param error [StandardError]
          # @param resolved_source [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          # @param cache_key [String]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def error_result(error, resolved_source, cache_key)
            Contracts::RenderResult.new(
              status: :error,
              payload: nil,
              message: Html2rss::Web::HttpError::DEFAULT_MESSAGE,
              ttl_seconds: resolved_source.ttl_seconds,
              cache_key: cache_key,
              error_message: error.message
            )
          end
        end
      end
    end
  end
end
