# frozen_string_literal: true

require_relative '../../../security/account_manager'
require_relative '../../../security/auth'
require_relative '../../../errors/exceptions'
require_relative '../../../domain/feed_contracts'
require_relative '../../../rendering/feed_response_format'
require_relative '../../../feeds/json_renderer'
require_relative '../../../feeds/request_parser'
require_relative '../../../feeds/resolver'
require_relative '../../../feeds/rss_renderer'
require_relative '../../../feeds/service'
require_relative '../../../http/feed_response'
require_relative '../../../telemetry/observability'

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
                emit_result(resolved_source, result)
                Http::FeedResponse.call(
                  response: request.response,
                  representation: feed_request.representation,
                  result: result
                )
              rescue StandardError => error
                emit_render_failure(error)
                raise
              end

              private

              # @param request [Rack::Request]
              # @param token [String]
              # @return [Array<(Html2rss::Web::FeedContracts::Request, Html2rss::Web::FeedContracts::ResolvedSource, Html2rss::Web::FeedContracts::RenderResult)>]
              def feed_pipeline(request, token)
                feed_request = ::Html2rss::Web::Feeds::RequestParser.call(
                  request: request,
                  target_kind: :token,
                  identifier: token
                )
                resolved_source = ::Html2rss::Web::Feeds::Resolver.call(feed_request)
                result = ::Html2rss::Web::Feeds::Service.call(resolved_source)

                [feed_request, resolved_source, result]
              end

              # @param resolved_source [Html2rss::Web::FeedContracts::ResolvedSource]
              # @param result [Html2rss::Web::FeedContracts::RenderResult]
              # @return [void]
              def emit_result(resolved_source, result)
                return emit_success_from(resolved_source) unless result.status == :error

                emit_render_failure(
                  InternalServerError.new(result.error_message || result.message || HttpError::DEFAULT_MESSAGE)
                )
              end

              # @param resolved_source [Html2rss::Web::FeedContracts::ResolvedSource]
              # @return [void]
              def emit_success_from(resolved_source)
                emit_render_success(
                  resolved_source.generator_input[:strategy],
                  resolved_source.generator_input.dig(:channel, :url)
                )
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
