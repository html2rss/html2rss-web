# frozen_string_literal: true

require 'time'
require 'json'

require_relative '../../../auth'
require_relative '../../../auto_source'
require_relative '../../../exceptions'
require_relative '../../../url_validator'

module Html2rss
  module Web
    module Api
      module V1
        module Feeds
          module CreateFeed
            class << self
              def call(request)
                account = require_account(request)
                ensure_auto_source_enabled!
                params = build_create_params(request_params(request), account)

                feed_data = AutoSource.create_stable_feed(params[:name], params[:url], account, params[:strategy])
                raise InternalServerError, 'Failed to create feed' unless feed_data

                json_response(request, feed_response_payload(feed_data), status: 201)
              end

              def extract_site_title(url)
                Html2rss::Url.for_channel(url).channel_titleized
              rescue StandardError
                nil
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

                {
                  url: url,
                  name: V1::Feeds.extract_site_title(url),
                  strategy: normalize_strategy(params['strategy'])
                }
              end

              def normalize_strategy(raw_strategy)
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

              def json_response(request, payload, status: 200)
                request.response['Content-Type'] = 'application/json'
                request.response.status = status
                payload
              end
            end
          end
        end
      end
    end
  end
end
