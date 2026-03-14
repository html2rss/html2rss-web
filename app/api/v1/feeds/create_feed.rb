# frozen_string_literal: true

require 'time'
require 'json'

require_relative '../../../auth'
require_relative '../../../auto_source'
require_relative '../../../boundary_models'
require_relative '../../../exceptions'
require_relative '../../../url_validator'
require_relative '../../../observability'
require_relative '../response'

module Html2rss
  module Web
    module Api
      module V1
        module Feeds
          ##
          # Creates stable feed records from authenticated API requests with one predictable boundary contract.
          module CreateFeed
            FEED_ATTRIBUTE_KEYS =
              %i[id name url strategy feed_token public_url json_public_url created_at updated_at].freeze

            class << self
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

              def ensure_auto_source_enabled!
                raise ForbiddenError, Contract::MESSAGES[:auto_source_disabled] unless AutoSource.enabled?
              end

              def require_account(request)
                account = Auth.authenticate(request)
                raise UnauthorizedError, 'Authentication required' unless account

                account
              end

              def build_create_params(params, account)
                url = params['url'].to_s.strip
                raise BadRequestError, 'URL parameter is required' if url.empty?
                raise BadRequestError, 'Invalid URL format' unless UrlValidator.valid_url?(url)
                raise ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(account, url)

                BoundaryModels::FeedCreateParams.new(
                  url: url,
                  name: V1::Feeds.extract_site_title(url),
                  strategy: normalize_strategy(params['strategy'])
                )
              end

              def normalize_strategy(raw_strategy)
                strategy = raw_strategy.to_s.strip
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

              def feed_attributes(feed_data)
                timestamp = Time.now.iso8601
                typed_feed = feed_metadata(feed_data)

                typed_feed_attributes(typed_feed, timestamp).slice(*FEED_ATTRIBUTE_KEYS)
              end

              def request_params(request)
                return request.params unless json_request?(request)

                raw_body = request.body.read
                request.body.rewind
                return request.params if raw_body.strip.empty?

                parsed = JSON.parse(raw_body)
                raise BadRequestError, 'Invalid JSON payload' unless parsed.is_a?(Hash)

                request.params.merge(parsed)
              rescue JSON::ParserError
                raise BadRequestError, 'Invalid JSON payload'
              end

              def json_request?(request)
                content_type = request.env['CONTENT_TYPE'].to_s
                content_type.include?('application/json')
              end

              def build_feed_from_request(request)
                account = require_account(request)
                ensure_auto_source_enabled!
                params = build_create_params(request_params(request), account)

                feed_data = AutoSource.create_stable_feed(params.name, params.url, account, params.strategy)
                raise InternalServerError, 'Failed to create feed' unless feed_data

                [params, feed_data]
              end

              def emit_create_success(params)
                Observability.emit(
                  event_name: 'feed.create',
                  outcome: 'success',
                  details: { strategy: params.strategy, url: params.url },
                  level: :info
                )
              end

              def emit_create_failure(error)
                Observability.emit(
                  event_name: 'feed.create',
                  outcome: 'failure',
                  details: { error_class: error.class.name, error_message: error.message },
                  level: :warn
                )
              end

              def feed_metadata(feed_data)
                return feed_data if feed_data.is_a?(BoundaryModels::FeedMetadata)

                BoundaryModels::FeedMetadata.new(**feed_data)
              end

              def typed_feed_attributes(typed_feed, timestamp)
                typed_feed.to_h.merge(created_at: timestamp, updated_at: timestamp)
              end
            end
          end
        end
      end
    end
  end
end
