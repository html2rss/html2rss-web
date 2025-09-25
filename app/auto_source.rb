# frozen_string_literal: true

require 'uri'
require_relative 'auth'
require_relative 'feed_generator'

module Html2rss
  module Web
    ##
    # Auto source functionality for generating RSS feeds from any website
    module AutoSource
      module_function

      # @return [Boolean]
      def enabled?
        if development?
          ENV.fetch('AUTO_SOURCE_ENABLED', nil) != 'false'
        else
          ENV.fetch('AUTO_SOURCE_ENABLED', nil) == 'true'
        end
      end

      ##
      # Authenticate request with token
      # @param request [Roda::Request] request object
      # @return [Hash, nil] account data if authenticated
      def authenticate_with_token(request)
        Auth.authenticate(request)
      end

      # @param request [Roda::Request]
      # @return [Boolean]
      def allowed_origin?(request)
        origin = request.env['HTTP_HOST'] || request.env['HTTP_X_FORWARDED_HOST']
        origins = allowed_origins
        origins.empty? || origins.include?(origin)
      end

      # @return [Array<String>]
      def allowed_origins
        if development?
          default_origins = 'localhost:3000,localhost:3001,127.0.0.1:3000,127.0.0.1:3001'
          origins = ENV.fetch('AUTO_SOURCE_ALLOWED_ORIGINS', default_origins)
        else
          origins = ENV.fetch('AUTO_SOURCE_ALLOWED_ORIGINS', '')
        end
        origins.split(',').map(&:strip)
      end

      # @param token_data [Hash]
      # @param url [String]
      # @return [Boolean]
      def url_allowed_for_token?(token_data, url)
        account = Auth.get_account_by_username(token_data[:username])
        return false unless account

        Auth.url_allowed?(account, url)
      end

      def create_stable_feed(name, url, token_data, strategy = 'ssrf_filter')
        return nil unless url_allowed_for_token?(token_data, url)

        feed_id = Auth.generate_feed_id(token_data[:username], url, token_data[:token])
        feed_token = Auth.generate_feed_token(token_data[:username], url)
        return nil unless feed_token

        build_feed_data(name, url, token_data, strategy, feed_id, feed_token)
      end

      def generate_feed_from_stable_id(feed_id, token_data)
        return nil unless token_data

        # Reconstruct feed data from token and feed_id
        # Stateless operation
        {
          id: feed_id,
          url: nil, # Will be provided in request
          username: token_data[:username],
          strategy: 'ssrf_filter'
        }
      end

      def generate_feed_content(url, strategy = 'ssrf_filter')
        feed_content = call_strategy(url, strategy)
        FeedGenerator.process_feed_content(url, strategy, feed_content, site_title: extract_site_title(url))
      end

      def call_strategy(url, strategy)
        FeedGenerator.call_strategy(url, strategy)
      end

      def extract_site_title(url)
        FeedGenerator.extract_site_title(url)
      end

      def build_feed_data(name, url, token_data, strategy, feed_id, feed_token)
        # Token is now the path parameter, URL is embedded in the token
        public_url = "/api/v1/feeds/#{feed_token}"

        {
          id: feed_id,
          name: name,
          url: url,
          username: token_data[:username],
          strategy: strategy,
          public_url: public_url
        }
      end

      def error_feed(message)
        FeedGenerator.error_feed(message)
      end

      def access_denied_feed(url)
        FeedGenerator.access_denied_feed(url)
      end

      def development?
        EnvironmentValidator.development?
      end
    end
  end
end
