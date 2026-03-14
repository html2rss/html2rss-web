# frozen_string_literal: true

require_relative '../../../account_manager'
require_relative '../../../auth'
require_relative '../../../auto_source'
require_relative '../../../exceptions'
require_relative '../../../feed_response_format'
require_relative '../../../feed_generator'
require_relative '../../../http_cache'
require_relative '../../../observability'
require_relative '../../../url_validator'

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
                format = FeedResponseFormat.for_request(request)
                normalized_token = FeedResponseFormat.strip_known_extension(token)
                feed_token, strategy = resolve_authorized_feed(normalized_token)
                rendered = render_generated_feed(request, feed_token.url, strategy, format)
                emit_render_success(strategy, feed_token.url)
                rendered
              rescue StandardError => error
                emit_render_failure(error)
                raise
              end

              private

              # @return [void]
              def ensure_auto_source_enabled!
                raise ForbiddenError, Contract::MESSAGES[:auto_source_disabled] unless AutoSource.enabled?
              end

              # @param token [String]
              # @return [Html2rss::Web::FeedToken]
              def validated_token_for(token)
                feed_token = Auth.validate_and_decode_feed_token(token)
                raise UnauthorizedError, 'Invalid token' unless feed_token

                feed_token
              end

              # @param feed_token [Html2rss::Web::FeedToken]
              # @return [Hash{Symbol=>Object}] account attributes.
              def account_for(feed_token)
                account = AccountManager.get_account_by_username(feed_token.username)
                raise UnauthorizedError, 'Account not found' unless account

                account
              end

              # @param account [Hash{Symbol=>Object}]
              # @param url [String]
              # @return [void]
              def ensure_access!(account, url)
                raise ForbiddenError, 'Access Denied' unless UrlValidator.url_allowed?(account, url)
              end

              # @param feed_token [Html2rss::Web::FeedToken]
              # @return [String] validated strategy identifier.
              def resolve_token_strategy(feed_token)
                strategy = feed_token.strategy.to_s.strip
                strategy = default_strategy if strategy.empty?

                raise BadRequestError, 'Unsupported strategy' unless supported_strategies.include?(strategy)

                strategy
              end

              # @return [Array<String>] supported strategy identifiers.
              def supported_strategies
                Html2rss::RequestService.strategy_names.map(&:to_s)
              end

              # @return [String] default strategy identifier.
              def default_strategy
                Html2rss::RequestService.default_strategy_name.to_s
              end

              # Builds HTTP response headers and returns XML body.
              #
              # @param request [Rack::Request]
              # @param url [String]
              # @param strategy [String]
              # @param format [Symbol]
              # @return [String] rendered feed body.
              def render_generated_feed(request, url, strategy, format)
                rendered_feed = AutoSource.generate_feed_result(url, strategy, format:)

                request.response['Content-Type'] = FeedResponseFormat.content_type(format)
                HttpCache.expires(request.response, rendered_feed.ttl_seconds, cache_control: 'public')
                HttpCache.vary(request.response, 'Accept')

                rendered_feed.body
              end

              # @param token [String]
              # @return [Array<(Html2rss::Web::FeedToken, String)>]
              def resolve_authorized_feed(token)
                feed_token = validated_token_for(token)
                account = account_for(feed_token)
                ensure_access!(account, feed_token.url)
                ensure_auto_source_enabled!

                strategy = resolve_token_strategy(feed_token)
                [feed_token, strategy]
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
