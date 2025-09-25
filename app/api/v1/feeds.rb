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
          module_function

          def show(request, token)
            handle_token_based_feed(request, token)
          end

          def create(request)
            raise ForbiddenError, 'Auto source feature is disabled' unless AutoSource.enabled?

            account = authenticate_request(request)
            params = extract_create_params(request)
            validate_create_params(params, account)

            feed_data = AutoSource.create_stable_feed(params[:name], params[:url], account, params[:strategy])
            raise InternalServerError, 'Failed to create feed' unless feed_data

            build_create_response(request, feed_data)
          end

          def handle_token_based_feed(request, token)
            raise ForbiddenError, 'Auto source feature is disabled' unless AutoSource.enabled?

            feed_token = validate_feed_token(token)
            account = get_account_for_token(feed_token)
            validate_account_access(account, feed_token.url)

            generate_feed_response(request, feed_token.url)
          end

          def validate_feed_token(token)
            feed_token = FeedToken.decode(token)
            raise UnauthorizedError, 'Invalid token' unless feed_token

            validated_token = FeedToken.validate_and_decode(token, feed_token.url, Auth.secret_key)
            raise UnauthorizedError, 'Invalid token' unless validated_token

            validated_token
          end

          def get_account_for_token(feed_token)
            account = AccountManager.get_account_by_username(feed_token.username)
            raise UnauthorizedError, 'Account not found' unless account

            account
          end

          def validate_account_access(account, url)
            raise ForbiddenError, 'Access Denied' unless UrlValidator.url_allowed?(account, url)
          end

          def generate_feed_response(request, url)
            strategy = select_strategy(request.params['strategy'])
            rss_content = AutoSource.generate_feed_content(url, strategy)

            request.response['Content-Type'] = 'application/xml'

            # TODO: get ttl from feed
            HttpCache.expires(request.response, 600, cache_control: 'public')

            rss_content.to_s
          end

          def authenticate_request(request)
            account = Auth.authenticate(request)
            raise UnauthorizedError, 'Authentication required' unless account

            account
          end

          private

          def extract_create_params(request)
            url = request.params['url']
            strategy = select_strategy(request.params['strategy'])
            {
              url: url,
              name: extract_site_title(url),
              strategy: strategy
            }
          end

          def validate_create_params(params, account)
            raise BadRequestError, 'URL parameter is required' if params[:url].nil? || params[:url].empty?
            raise BadRequestError, 'Invalid URL format' unless UrlValidator.valid_url?(params[:url])
            raise ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(account,
                                                                                                      params[:url])
          end

          def build_create_response(request, feed_data)
            request.response['Content-Type'] = 'application/json'
            request.response.status = 201
            feed_response_payload(feed_data)
          end

          def select_strategy(raw_strategy)
            strategy = raw_strategy.to_s.strip
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

          def feed_response_payload(feed_data)
            {
              success: true,
              data: { feed: {
                id: feed_data[:id],
                name: feed_data[:name],
                url: feed_data[:url],
                strategy: feed_data[:strategy],
                public_url: feed_data[:public_url],
                created_at: Time.now.iso8601,
                updated_at: Time.now.iso8601
              } },
              meta: { created: true }
            }
          end

          def extract_site_title(url)
            Html2rss::Url.for_channel(url).channel_titleized
          rescue StandardError
            nil
          end

          module_function :extract_create_params, :validate_create_params, :build_create_response,
                          :authenticate_request, :select_strategy, :supported_strategies, :default_strategy,
                          :feed_response_payload, :extract_site_title
          private_class_method :extract_create_params, :validate_create_params, :build_create_response,
                               :authenticate_request, :select_strategy, :supported_strategies, :default_strategy,
                               :feed_response_payload, :extract_site_title
        end
      end
    end
  end
end
