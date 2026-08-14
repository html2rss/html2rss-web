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
          FEED_ATTRIBUTE_KEYS = %i[id name url feed_token public_url json_public_url created_at updated_at].freeze
          ABSOLUTE_URL_REGEXP = %r{\A[a-z][a-z0-9+\-.]*://}i
          HOSTNAME_INPUT_REGEXP = %r{
            \A(localhost(?::\d+)?|(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?|(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?)
            (?:[/?#].*)?\z
          }ix

          class << self
            # Creates a feed and returns a normalized API success payload.
            #
            # @param request [Rack::Request] HTTP request with auth context.
            # @return [Hash{Symbol=>Object}] API response payload.
            def call(request)
              account = require_account(request)
              params = build_create_params(request, account)
              feed_data = create_feed(params, account)

              emit_create(status: :success, details: { url: params.url })
              Response.success(response: request.response, status: 201,
                               data: { feed: feed_attributes(feed_data) }, meta: { created: true })
            rescue StandardError => error
              emit_create(status: :failure, details: { error_class: error.class.name, error_message: error.message })
              raise
            end

            private

            def require_account(request)
              account = Auth.authenticate(request)
              raise Html2rss::Web::UnauthorizedError, 'Authentication required' unless account

              account
            end

            def build_create_params(request, account)
              url = validated_url(request_params(request)['url'], account)
              FeedMetadata::CreateParams.new(url:, name: Feeds::ChannelTitle.for(url))
            end

            def request_params(request)
              return request.params unless json_request?(request)

              request.GET.merge(parsed_json_body(request))
            end

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
              raise Html2rss::Web::ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(
                account, url
              )

              url
            end

            # @param raw_url [String, nil]
            # @return [String]
            def normalized_input_url(raw_url)
              url = raw_url.to_s.strip
              return url if url.empty? || ABSOLUTE_URL_REGEXP.match?(url)
              return "https:#{url}" if url.start_with?('//')

              HOSTNAME_INPUT_REGEXP.match?(url) ? "https://#{url}" : url
            end

            # @param params [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            # @param account [Hash]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def create_feed(params, account)
              raise Html2rss::Web::AutoSourceDisabledError unless Flags.auto_source_enabled?

              feed_token = Auth.generate_feed_token(account[:username], params.url)
              raise Html2rss::Web::InternalServerError, 'Failed to create feed' unless feed_token

              FeedMetadata.build(account:, name: params.name, url: params.url, feed_token:)
            end

            # @param feed_data [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            # @return [Hash{Symbol=>Object}]
            def feed_attributes(feed_data)
              timestamp = Time.now.iso8601
              feed_data.to_h.merge(created_at: timestamp, updated_at: timestamp).slice(*FEED_ATTRIBUTE_KEYS)
            end

            # @param status [Symbol]
            # @param details [Hash{Symbol=>Object}]
            # @return [void]
            def emit_create(status:, details:)
              level = status == :success ? :info : :warn
              Observability.emit(event_name: 'feed.create', outcome: status.to_s, details:, level:)
            end
          end
        end
      end
    end
  end
end
