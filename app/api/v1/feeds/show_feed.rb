# frozen_string_literal: true

require_relative '../../../account_manager'
require_relative '../../../auth'
require_relative '../../../exceptions'
require_relative '../../../feed_response_format'
require_relative '../../../feeds/json_renderer'
require_relative '../../../feeds/request_parser'
require_relative '../../../feeds/resolver'
require_relative '../../../feeds/rss_renderer'
require_relative '../../../feeds/service'
require_relative '../../../http_cache'
require_relative '../../../observability'

module Html2rss
  module Web
    module Api
      module V1
        module Feeds
          ##
          # Renders feed content for a signed token.
          #
          # This module stays narrow by handling only edge validation and
          # orchestration, then delegating generation to existing services.
          module ShowFeed
            class << self
              # Resolves and renders XML feed output for a token request.
              #
              # @param request [Rack::Request]
              # @param token [String] signed public feed token.
              # @return [String] serialized feed response body.
              def call(request, token)
                feed_request, resolved_source, result = feed_pipeline(request, token)
                configure_response(request, feed_request.representation, result.ttl_seconds)
                emit_success_from(resolved_source)
                render_result(result, feed_request.representation)
              rescue StandardError => error
                emit_render_failure(error)
                raise
              end

              private

              # @param request [Rack::Request]
              # @param token [String]
              # @return [Array<(Html2rss::Web::Feeds::Request, Html2rss::Web::Feeds::ResolvedSource, Html2rss::Web::Feeds::Result)>]
              def feed_pipeline(request, token)
                feed_request = ::Html2rss::Web::Feeds::RequestParser.call(
                  request: request,
                  target_kind: :token,
                  identifier: token
                )
                resolved_source = ::Html2rss::Web::Feeds::Resolver.call(feed_request)
                result = ::Html2rss::Web::Feeds::Service.call(resolved_source)
                raise InternalServerError, result.message if result.status == :error

                [feed_request, resolved_source, result]
              end

              # @param request [Rack::Request]
              # @param format [Symbol]
              # @param ttl_seconds [Integer]
              # @return [void]
              def configure_response(request, format, ttl_seconds)
                request.response['Content-Type'] = FeedResponseFormat.content_type(format)
                HttpCache.expires(request.response, ttl_seconds, cache_control: 'public')
                HttpCache.vary(request.response, 'Accept')
              end

              # @param resolved_source [Html2rss::Web::Feeds::ResolvedSource]
              # @return [void]
              def emit_success_from(resolved_source)
                emit_render_success(
                  resolved_source.generator_input[:strategy],
                  resolved_source.generator_input.dig(:channel, :url)
                )
              end

              # @param result [Html2rss::Web::Feeds::Result]
              # @param format [Symbol]
              # @return [String]
              def render_result(result, format)
                if format == ::Html2rss::Web::Feeds::ResponseFormat::JSON_FEED
                  return ::Html2rss::Web::Feeds::JsonRenderer.call(result)
                end

                ::Html2rss::Web::Feeds::RssRenderer.call(result)
              end

              # @param strategy [String]
              # @param url [String]
              # @return [void]
              def emit_render_success(strategy, url)
                Observability.emit(
                  event_name: 'feed.render',
                  outcome: 'success',
                  details: { strategy: strategy, url: url },
                  level: :info
                )
              end

              # @param error [StandardError]
              # @return [void]
              def emit_render_failure(error)
                Observability.emit(
                  event_name: 'feed.render',
                  outcome: 'failure',
                  details: { error_class: error.class.name, error_message: error.message },
                  level: :warn
                )
              end
            end
          end
        end
      end
    end
  end
end
