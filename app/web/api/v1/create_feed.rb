# frozen_string_literal: true

require 'time'
require 'json'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Creates stable feed records from authenticated API requests.
        module CreateFeed # rubocop:disable Metrics/ModuleLength
          FEED_ATTRIBUTE_KEYS =
            %i[id name url strategy feed_token public_url json_public_url created_at updated_at].freeze
          class << self # rubocop:disable Metrics/ClassLength
            # Creates a feed and returns a normalized API success payload.
            #
            # @param request [Rack::Request] HTTP request with auth context.
            # @return [Hash{Symbol=>Object}] API response payload.
            def call(request)
              params, feed_data = build_feed_from_request(request)
              emit_create_success(params)
              Response.success(response: request.response,
                               status: 201,
                               data: { feed: feed_attributes(feed_data) },
                               meta: { created: true })
            rescue StandardError => error
              emit_create_failure(error)
              raise
            end

            private

            # @return [void]
            def ensure_auto_source_enabled!
              raise Html2rss::Web::ForbiddenError, Contract::MESSAGES[:auto_source_disabled] unless AutoSource.enabled?
            end

            # @param request [Rack::Request]
            # @return [Hash]
            def require_account(request)
              account = Auth.authenticate(request)
              raise Html2rss::Web::UnauthorizedError, 'Authentication required' unless account

              account
            end

            # @param params [Hash]
            # @param account [Hash]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            def build_create_params(params, account)
              url = validated_url(params['url'], account)
              FeedMetadata::CreateParams.new(
                url: url,
                name: FeedMetadata.site_title_for(url),
                strategy: normalize_strategy(params['strategy'])
              )
            end

            # @param raw_url [String, nil]
            # @param account [Hash]
            # @return [String]
            def validated_url(raw_url, account)
              url = raw_url.to_s.strip
              raise Html2rss::Web::BadRequestError, 'URL parameter is required' if url.empty?
              raise Html2rss::Web::BadRequestError, 'Invalid URL format' unless UrlValidator.valid_url?(url)
              unless UrlValidator.url_allowed?(account, url)
                raise Html2rss::Web::ForbiddenError, 'URL not allowed for this account'
              end

              url
            end

            # @param raw_strategy [String, nil]
            # @return [String]
            def normalize_strategy(raw_strategy)
              strategy = raw_strategy.to_s.strip
              strategy = default_strategy if strategy.empty?

              raise Html2rss::Web::BadRequestError, 'Unsupported strategy' unless supported_strategy?(strategy)

              strategy
            end

            # @return [Array<String>] supported strategy identifiers.
            def supported_strategies
              Html2rss::RequestService.strategy_names.map(&:to_s)
            end

            # @param strategy [String]
            # @return [Boolean]
            def supported_strategy?(strategy)
              supported_strategies.include?(strategy)
            end

            # @return [String] default strategy identifier.
            def default_strategy
              Html2rss::RequestService.default_strategy_name.to_s
            end

            # @param feed_data [Hash, Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            # @return [Hash{Symbol=>Object}]
            def feed_attributes(feed_data)
              timestamp = Time.now.iso8601
              typed_feed = feed_metadata(feed_data)
              typed_feed_attributes(typed_feed, timestamp).slice(*FEED_ATTRIBUTE_KEYS)
            end

            # @param request [Rack::Request]
            # @return [Hash]
            def request_params(request)
              return request.params unless json_request?(request)

              raw_body = request.body.read
              request.body.rewind
              return request.params if raw_body.strip.empty?

              parsed = JSON.parse(raw_body)
              raise Html2rss::Web::BadRequestError, 'Invalid JSON payload' unless parsed.is_a?(Hash)

              request.params.merge(parsed)
            rescue JSON::ParserError
              raise Html2rss::Web::BadRequestError, 'Invalid JSON payload'
            end

            # @param request [Rack::Request]
            # @return [Boolean]
            def json_request?(request)
              content_type = request.env['CONTENT_TYPE'].to_s
              content_type.include?('application/json')
            end

            # @param request [Rack::Request]
            # @return [Array<(Html2rss::Web::Api::V1::FeedMetadata::CreateParams, Object)>]
            def build_feed_from_request(request)
              account = require_account(request)
              ensure_auto_source_enabled!
              params = build_create_params(request_params(request), account)

              feed_data = AutoSource.create_stable_feed(params.name, params.url, account, params.strategy)
              raise Html2rss::Web::InternalServerError, 'Failed to create feed' unless feed_data

              [params, feed_data]
            end

            # @param params [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            # @return [void]
            def emit_create_success(params)
              Observability.emit(
                event_name: 'feed.create',
                outcome: 'success',
                details: { strategy: params.strategy, url: params.url },
                level: :info
              )
            end

            # @param error [StandardError]
            # @return [void]
            def emit_create_failure(error)
              Observability.emit(
                event_name: 'feed.create',
                outcome: 'failure',
                details: { error_class: error.class.name, error_message: error.message },
                level: :warn
              )
            end

            # @param feed_data [Hash, Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def feed_metadata(feed_data)
              return feed_data if feed_data.is_a?(FeedMetadata::Metadata)

              FeedMetadata::Metadata.new(**feed_data)
            end

            # @param typed_feed [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            # @param timestamp [String]
            # @return [Hash{Symbol=>Object}]
            def typed_feed_attributes(typed_feed, timestamp)
              typed_feed.to_h.merge(created_at: timestamp, updated_at: timestamp)
            end
          end
        end
      end
    end
  end
end
