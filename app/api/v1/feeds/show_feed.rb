# frozen_string_literal: true

require_relative '../../../account_manager'
require_relative '../../../auth'
require_relative '../../../auto_source'
require_relative '../../../cache_ttl'
require_relative '../../../exceptions'
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
            DEFAULT_TTL_SECONDS = 3600

            class << self
              # Resolves and renders XML feed output for a token request.
              #
              # @param request [Rack::Request]
              # @param token [String] signed public feed token.
              # @return [String] XML feed response body.
              def call(request, token)
                feed_token, strategy = resolve_authorized_feed(token)
                rendered = render_generated_feed(request, feed_token.url, strategy)
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
              # @return [String] rendered XML.
              def render_generated_feed(request, url, strategy)
                feed_object = AutoSource.generate_feed_object(url, strategy)
                rendered_feed = FeedGenerator.process_feed_content(url, strategy, feed_object)

                request.response['Content-Type'] = 'application/xml'
                HttpCache.expires(request.response, ttl_from_feed(feed_object), cache_control: 'public')

                rendered_feed.to_s
              end

              # @param feed_object [Object] object exposing channel ttl when available.
              # @return [Integer] cache TTL in seconds.
              def ttl_from_feed(feed_object)
                ttl_value = feed_object.respond_to?(:channel) ? feed_object.channel&.ttl : nil
                CacheTtl.seconds_from_minutes(ttl_value, default: DEFAULT_TTL_SECONDS)
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
