# frozen_string_literal: true

require_relative '../../auth'
require_relative '../../auto_source'
require_relative '../../feeds'
require_relative '../../xml_builder'
require_relative '../../exceptions'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # RESTful API v1 for feeds resource
        # Handles CRUD operations for RSS feeds
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

          def show(request, feed_id)
            if json_request?(request)
              show_feed_metadata(feed_id)
            else
              generate_feed_content(request, feed_id)
            end
          end

          def create(request)
            account = Auth.authenticate(request)
            raise UnauthorizedError, 'Authentication required' unless account

            url = request.params['url']
            name = request.params['name'] || extract_site_title(url)
            strategy = request.params['strategy'] || 'ssrf_filter'

            raise BadRequestError, 'URL parameter is required' if url.nil? || url.empty?
            raise BadRequestError, 'Invalid URL format' unless Auth.valid_url?(url)
            raise ForbiddenError, 'URL not allowed for this account' unless Auth.url_allowed?(account, url)

            feed_data = AutoSource.create_stable_feed(name, url, account, strategy)
            raise InternalServerError, 'Failed to create feed' unless feed_data

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

            # Set appropriate headers for XML response
            request.response['Content-Type'] = 'application/xml'
            request.response['Cache-Control'] = "public, max-age=#{ttl}"

            # Convert RSS object to string
            rss_content.to_s
          end

          def extract_site_title(url)
            AutoSource.extract_site_title(url)
          end
        end
      end
    end
  end
end
