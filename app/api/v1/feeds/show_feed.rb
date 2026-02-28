# frozen_string_literal: true

require_relative '../../../account_manager'
require_relative '../../../auth'
require_relative '../../../auto_source'
require_relative '../../../cache_ttl'
require_relative '../../../exceptions'
require_relative '../../../feed_generator'
require_relative '../../../http_cache'
require_relative '../../../url_validator'

module Html2rss
  module Web
    module Api
      module V1
        module Feeds
          module ShowFeed
            DEFAULT_TTL_SECONDS = 3600

            class << self
              def call(request, token)
                feed_token = validated_token_for(token)
                account = account_for(feed_token)
                ensure_access!(account, feed_token.url)
                ensure_auto_source_enabled!

                strategy = resolve_token_strategy(feed_token)
                render_generated_feed(request, feed_token.url, strategy)
              end

              private

              def ensure_auto_source_enabled!
                raise ForbiddenError, Contract::MESSAGES[:auto_source_disabled] unless AutoSource.enabled?
              end

              def validated_token_for(token)
                feed_token = Auth.validate_and_decode_feed_token(token)
                raise UnauthorizedError, 'Invalid token' unless feed_token

                feed_token
              end

              def account_for(feed_token)
                account = AccountManager.get_account_by_username(feed_token.username)
                raise UnauthorizedError, 'Account not found' unless account

                account
              end

              def ensure_access!(account, url)
                raise ForbiddenError, 'Access Denied' unless UrlValidator.url_allowed?(account, url)
              end

              def resolve_token_strategy(feed_token)
                strategy = feed_token.strategy.to_s.strip
                strategy = default_strategy if strategy.empty?

                raise BadRequestError, 'Unsupported strategy' unless supported_strategies.include?(strategy)

                strategy
              end

              def supported_strategies
                Html2rss::RequestService.strategy_names.map(&:to_s)
              end

              def default_strategy
                Html2rss::RequestService.default_strategy_name.to_s
              end

              def render_generated_feed(request, url, strategy)
                feed_object = AutoSource.generate_feed_object(url, strategy)
                rendered_feed = FeedGenerator.process_feed_content(url, strategy, feed_object)

                request.response['Content-Type'] = 'application/xml'
                HttpCache.expires(request.response, ttl_from_feed(feed_object), cache_control: 'public')

                rendered_feed.to_s
              end

              def ttl_from_feed(feed_object)
                ttl_value = feed_object.respond_to?(:channel) ? feed_object.channel&.ttl : nil
                CacheTtl.seconds_from_minutes(ttl_value, default: DEFAULT_TTL_SECONDS)
              end
            end
          end
        end
      end
    end
  end
end
