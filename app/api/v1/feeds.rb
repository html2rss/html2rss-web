# frozen_string_literal: true

require 'time'
require 'html2rss/url'

require_relative '../../account_manager'
require_relative '../../auth'
require_relative '../../auto_source'
require_relative '../../feeds'
require_relative '../../exceptions'
require_relative '../../feed_token'
require_relative '../../url_validator'

module Html2rss
  module Web
    module Api
      module V1
        # RESTful API v1 for feeds
        module Feeds
          class << self
            def show(request, token)
              ensure_auto_source_enabled!

              feed_token = validated_token_for(token)
              account = account_for(feed_token)
              ensure_access!(account, feed_token.url)

              render_generated_feed(request, feed_token.url)
            end

            def create(request)
              ensure_auto_source_enabled!

              account = require_account(request)
              params = build_create_params(request, account)

              feed_data = AutoSource.create_stable_feed(params[:name], params[:url], account, params[:strategy])
              raise InternalServerError, 'Failed to create feed' unless feed_data

              json_response(request, feed_response_payload(feed_data), status: 201)
            end

            private

            def ensure_auto_source_enabled!
              raise ForbiddenError, 'Auto source feature is disabled' unless AutoSource.enabled?
            end

            def json_response(request, payload, status: 200)
              request.response['Content-Type'] = 'application/json'
              request.response.status = status
              payload
            end

            def build_create_params(request, account)
              url = request.params['url'].to_s.strip
              raise BadRequestError, 'URL parameter is required' if url.empty?
              raise BadRequestError, 'Invalid URL format' unless UrlValidator.valid_url?(url)
              raise ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(account, url)

              {
                url: url,
                name: extract_site_title(url),
                strategy: normalize_strategy(request.params['strategy'])
              }
            end

            def normalize_strategy(raw_strategy)
              strategy = raw_strategy.to_s.strip
              strategy = default_strategy if strategy.empty?

              raise BadRequestError, 'Unsupported strategy' unless supported_strategies.include?(strategy)

              strategy
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

            def render_generated_feed(request, url)
              rss_content = AutoSource.generate_feed_content(url, normalize_strategy(request.params['strategy']))

              request.response['Content-Type'] = 'application/xml'

              # TODO: get ttl from feed
              HttpCache.expires(request.response, 600, cache_control: 'public')

              rss_content.to_s
            end

            def require_account(request)
              account = Auth.authenticate(request)
              raise UnauthorizedError, 'Authentication required' unless account

              account
            end

            def supported_strategies
              Html2rss::RequestService.strategy_names.map(&:to_s)
            end

            def default_strategy
              Html2rss::RequestService.default_strategy_name.to_s
            end

            def feed_response_payload(feed_data)
              {
                success: true,
                data: { feed: feed_attributes(feed_data) },
                meta: { created: true }
              }
            end

            def feed_attributes(feed_data)
              timestamp = Time.now.iso8601

              {
                id: feed_data[:id],
                name: feed_data[:name],
                url: feed_data[:url],
                strategy: feed_data[:strategy],
                public_url: feed_data[:public_url],
                created_at: timestamp,
                updated_at: timestamp
              }
            end

            def extract_site_title(url)
              Html2rss::Url.for_channel(url).channel_titleized
            rescue StandardError
              nil
            end
          end
        end
      end
    end
  end
end
