# frozen_string_literal: true

require 'time'
require 'json'
require 'html2rss/url'

require_relative '../../../auth'
require_relative '../../../auto_source'
require_relative '../../../boundary_models'
require_relative '../../../exceptions'
require_relative '../../../url_validator'
require_relative '../response'

module Html2rss
  module Web
    module Api
      module V1
        module Feeds
          ##
          # Creates stable feed records from authenticated API requests.
          #
          # The implementation intentionally keeps parsing, authorization, and
          # normalization in a single boundary object so callers can rely on one
          # predictable contract instead of coordinating multiple services.
          module CreateFeed
            class << self
              # Creates a feed and returns a normalized API success payload.
              #
              # @param request [Rack::Request] HTTP request with auth context.
              # @return [Hash{Symbol=>Object}] API response payload.
              def call(request)
                account = require_account(request)
                ensure_auto_source_enabled!
                params = build_create_params(request_params(request), account)

                feed_data = AutoSource.create_stable_feed(params.name, params.url, account, params.strategy)
                raise InternalServerError, 'Failed to create feed' unless feed_data

                Response.success(response: request.response,
                                 status: 201,
                                 data: { feed: feed_attributes(feed_data) },
                                 meta: { created: true })
              end

              # Extracts a best-effort human-readable title from the URL.
              #
              # @param url [String] target source URL.
              # @return [String, nil] inferred title or nil when unavailable.
              def extract_site_title(url)
                Html2rss::Url.for_channel(url).channel_titleized
              rescue StandardError
                nil
              end

              private

              # Enforces feature availability at the API edge to fail fast.
              #
              # @return [void]
              def ensure_auto_source_enabled!
                raise ForbiddenError, Contract::MESSAGES[:auto_source_disabled] unless AutoSource.enabled?
              end

              # Resolves the authenticated account from the request.
              #
              # @param request [Rack::Request]
              # @return [Hash{Symbol=>Object}] authenticated account attributes.
              def require_account(request)
                account = Auth.authenticate(request)
                raise UnauthorizedError, 'Authentication required' unless account

                account
              end

              # Validates and normalizes feed creation parameters.
              #
              # @param params [Hash{String=>Object}] merged request parameters.
              # @param account [Hash{Symbol=>Object}] authenticated account.
              # @return [Html2rss::Web::BoundaryModels::FeedCreateParams]
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

              # Normalizes a strategy value while preserving a default path.
              #
              # @param raw_strategy [String, nil]
              # @return [String]
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

              # Shapes feed attributes into the stable API schema.
              #
              # @param feed_data [Html2rss::Web::BoundaryModels::FeedMetadata, Hash{Symbol=>Object}] feed record.
              # @return [Hash{Symbol=>Object}] response-safe feed attributes.
              def feed_attributes(feed_data)
                typed_feed = feed_data.is_a?(BoundaryModels::FeedMetadata) ? feed_data : BoundaryModels::FeedMetadata.new(**feed_data)
                timestamp = Time.now.iso8601

                typed_feed.to_h.merge(
                  created_at: timestamp,
                  updated_at: timestamp
                ).slice(:id, :name, :url, :strategy, :public_url, :created_at, :updated_at)
              end

              # Parses params with optional JSON body override.
              #
              # @param request [Rack::Request]
              # @return [Hash{String=>Object}] merged request params.
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

              # @param request [Rack::Request]
              # @return [Boolean] whether request body should be parsed as JSON.
              def json_request?(request)
                content_type = request.env['CONTENT_TYPE'].to_s
                content_type.include?('application/json')
              end
            end
          end
        end
      end
    end
  end
end
