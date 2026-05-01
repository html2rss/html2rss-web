# frozen_string_literal: true

require 'json'
require 'time'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Creates stable feed records from authenticated API requests.
        module CreateFeed
          FEED_ATTRIBUTE_KEYS =
            %i[id name url feed_token public_url json_public_url created_at updated_at].freeze
          FEED_METADATA_KEYS =
            %i[id name url username feed_token public_url json_public_url].freeze

          class << self
            # Creates a feed and returns a normalized API success payload.
            #
            # @param request [Rack::Request] HTTP request with auth context.
            # @return [Hash{Symbol=>Object}] API response payload.
            # rubocop:disable Metrics/MethodLength
            def call(request)
              account = require_account(request)
              params = build_create_params(request, account)
              feed_data = create_feed(params, account)

              emit_create_success(params)
              Response.success(response: request.response,
                               status: 201,
                               data: {
                                 feed: feed_attributes(feed_data)
                               },
                               meta: { created: true })
            rescue StandardError => error
              emit_create_failure(error)
              raise
            end
            # rubocop:enable Metrics/MethodLength

            private

            # @param request [Rack::Request]
            # @return [Hash]
            def require_account(request)
              account = Auth.authenticate(request)
              raise Html2rss::Web::UnauthorizedError, 'Authentication required' unless account

              account
            end

            # @param request [Rack::Request]
            # @param account [Hash]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            def build_create_params(request, account)
              url = validated_url(request_params(request)['url'], account)
              FeedMetadata::CreateParams.new(url:, name: FeedMetadata.site_title_for(url))
            end

            # @param request [Rack::Request]
            # @return [Hash]
            def request_params(request)
              return request.params unless json_request?(request)

              request.GET.merge(parsed_json_body(request))
            end

            # @param request [Rack::Request]
            # @return [Hash]
            def parsed_json_body(request)
              raw_body = request.body.read
              request.body.rewind
              return {} if raw_body.strip.empty?

              parsed = JSON.parse(raw_body)
              raise Html2rss::Web::BadRequestError, 'Invalid JSON payload' unless parsed.is_a?(Hash)

              parsed
            rescue JSON::ParserError
              raise Html2rss::Web::BadRequestError, 'Invalid JSON payload'
            end

            # @param request [Rack::Request]
            # @return [Boolean]
            def json_request?(request)
              request.env['CONTENT_TYPE'].to_s.include?('application/json')
            end

            # @param raw_url [String, nil]
            # @param account [Hash]
            # @return [String]
            def validated_url(raw_url, account)
              url = normalized_input_url(raw_url)
              raise Html2rss::Web::BadRequestError, 'URL parameter is required' if url.empty?

              url = UrlValidator.canonical_url(url)
              raise Html2rss::Web::BadRequestError, 'Invalid URL format' unless url
              unless UrlValidator.url_allowed?(account, url)
                raise Html2rss::Web::ForbiddenError, 'URL not allowed for this account'
              end

              url
            end

            # @param raw_url [String, nil]
            # @return [String]
            def normalized_input_url(raw_url)
              url = raw_url.to_s.strip
              return url if url.empty?
              return "https:#{url}" if url.start_with?('//')
              return url if absolute_url?(url)

              hostname_input?(url) ? "https://#{url}" : url
            end

            # @param url [String]
            # @return [Boolean]
            def absolute_url?(url)
              url.match?(%r{\A[a-z][a-z0-9+\-.]*://}i)
            end

            # @param url [String]
            # @return [Boolean]
            def hostname_input?(url)
              %r{
                \A
                (localhost(?::\d+)?|(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?|(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?)
                (?:[/?#].*)?
                \z
              }ix.match?(url)
            end

            # @param params [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            # @param account [Hash]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def create_feed(params, account)
              raise Html2rss::Web::AutoSourceDisabledError unless AutoSource.enabled?

              feed_data = AutoSource.create_stable_feed(params.name, params.url, account)
              raise Html2rss::Web::InternalServerError, 'Failed to create feed' unless feed_data

              feed_data.is_a?(FeedMetadata::Metadata) ? feed_data : feed_metadata(feed_data)
            end

            # @param feed_data [Hash]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def feed_metadata(feed_data)
              FeedMetadata::Metadata.new(**feed_data.slice(*FEED_METADATA_KEYS))
            end

            # @param feed_data [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            # @return [Hash{Symbol=>Object}]
            def feed_attributes(feed_data)
              timestamp = Time.now.iso8601
              feed_data.to_h.merge(created_at: timestamp, updated_at: timestamp).slice(*FEED_ATTRIBUTE_KEYS)
            end

            # @param params [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            # @return [void]
            def emit_create_success(params)
              Observability.emit(
                event_name: 'feed.create',
                outcome: 'success',
                details: { url: params.url },
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
          end
        end
      end
    end
  end
end
