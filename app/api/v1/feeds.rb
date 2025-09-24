# frozen_string_literal: true

require_relative '../../auth'
require_relative '../../auto_source'
require_relative '../../feeds'
require_relative '../../xml_builder'
require_relative '../../exceptions'
require_relative '../../feed_token'

module Html2rss
  module Web
    module Api
      module V1
        # RESTful API v1 for feeds
        module Feeds
          module_function

          def index(_request)
            feeds = Html2rss::Web::Feeds.list_feeds.map do |feed|
              {
                id: feed[:name],
                name: feed[:name],
                description: feed[:description],
                url: "/api/v1/feeds/#{feed[:name]}",
                created_at: nil,
                updated_at: nil
              }
            end

            { success: true, data: { feeds: feeds }, meta: { total: feeds.count } }
          end

          def show(request, token)
            handle_token_based_feed(request, token)
          end

          def create(request)
            account = authenticate_request(request)
            params = extract_create_params(request)
            validate_create_params(params, account)

            feed_data = AutoSource.create_stable_feed(params[:name], params[:url], account, params[:strategy])
            raise InternalServerError, 'Failed to create feed' unless feed_data

            build_create_response(request, feed_data)
          end

          def json_request?(request)
            accept_header = request.env['HTTP_ACCEPT'].to_s
            accept_header.include?('application/json') && !accept_header.include?('application/xml')
          end

          def show_feed_metadata(feed_id)
            config = LocalConfig.find(feed_id)
            raise NotFoundError, 'Feed not found' unless config

            { success: true, data: { feed: {
              id: feed_id,
              name: feed_id,
              description: "RSS feed for #{feed_id}",
              url: "/api/v1/feeds/#{feed_id}",
              strategy: config[:strategy] || 'ssrf_filter',
              created_at: nil,
              updated_at: nil
            } } }
          end

          def generate_feed_content(request, feed_id)
            rss_content = Html2rss::Web::Feeds.generate_feed(feed_id, request.params)
            config = LocalConfig.find(feed_id)
            ttl = config&.dig(:channel, :ttl) || 3600

            request.response['Content-Type'] = 'application/xml'
            request.response['Cache-Control'] = "public, max-age=#{ttl}"

            rss_content.to_s
          end

          def handle_token_based_feed(request, token)
            feed_token = validate_feed_token(token)
            account = get_account_for_token(feed_token)
            validate_account_access(account, feed_token.url)

            generate_feed_response(request, feed_token.url)
          end

          def extract_site_title(url)
            AutoSource.extract_site_title(url)
          end

          def validate_feed_token(token)
            feed_token = FeedToken.decode(token)
            raise UnauthorizedError, 'Invalid token' unless feed_token

            validated_token = FeedToken.validate_and_decode(token, feed_token.url, Auth.secret_key)
            raise UnauthorizedError, 'Invalid token' unless validated_token

            validated_token
          end

          def get_account_for_token(feed_token)
            account = Auth.get_account_by_username(feed_token.username)
            raise UnauthorizedError, 'Account not found' unless account

            account
          end

          def validate_account_access(account, url)
            raise ForbiddenError, 'Access Denied' unless Auth.url_allowed?(account, url)
          end

          def generate_feed_response(request, url)
            strategy = request.params['strategy'] || 'ssrf_filter'
            rss_content = AutoSource.generate_feed_content(url, strategy)

            request.response['Content-Type'] = 'application/xml'
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
            {
              url: url,
              name: request.params['name'] || extract_site_title(url),
              strategy: request.params['strategy'] || 'ssrf_filter'
            }
          end

          def validate_create_params(params, account)
            raise BadRequestError, 'URL parameter is required' if params[:url].nil? || params[:url].empty?
            raise BadRequestError, 'Invalid URL format' unless Auth.valid_url?(params[:url])
            raise ForbiddenError, 'URL not allowed for this account' unless Auth.url_allowed?(account, params[:url])
          end

          def build_create_response(request, feed_data)
            request.response['Content-Type'] = 'application/json'
            { success: true, data: { feed: {
              id: feed_data[:id],
              name: feed_data[:name],
              url: feed_data[:url],
              strategy: feed_data[:strategy],
              public_url: feed_data[:public_url],
              created_at: Time.now.iso8601,
              updated_at: Time.now.iso8601
            } }, meta: { created: true } }
          end
        end
      end
    end
  end
end
