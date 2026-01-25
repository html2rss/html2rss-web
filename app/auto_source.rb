# frozen_string_literal: true

require 'digest'
require_relative 'account_manager'
require_relative 'auth'
require_relative 'feed_generator'
require_relative 'url_validator'

module Html2rss
  module Web
    ##
    # Auto source functionality for generating RSS feeds from any website
    module AutoSource
      class << self
        # @return [Boolean]
        def enabled?
          if EnvironmentValidator.development?
            ENV.fetch('AUTO_SOURCE_ENABLED', nil) != 'false'
          else
            ENV.fetch('AUTO_SOURCE_ENABLED', nil) == 'true'
          end
        end

        def create_stable_feed(name, url, token_data, strategy = 'ssrf_filter')
          return nil unless url_allowed_for_token?(token_data, url)

          feed_id = generate_feed_id(token_data[:username], url, token_data[:token])
          feed_token = Auth.generate_feed_token(token_data[:username], url, strategy: strategy)
          return nil unless feed_token

          identifiers = { feed_id: feed_id, feed_token: feed_token }

          build_feed_data(name, url, token_data, strategy, identifiers)
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

        def generate_feed_object(url, strategy = 'ssrf_filter')
          FeedGenerator.call_strategy(url, strategy)
        end

        def generate_feed_content(url, strategy = 'ssrf_filter')
          feed_content = FeedGenerator.call_strategy(url, strategy)
          FeedGenerator.process_feed_content(url, strategy, feed_content)
        end

        private

        # @param token_data [Hash]
        # @param url [String]
        # @return [Boolean]
        def url_allowed_for_token?(token_data, url)
          account = AccountManager.get_account_by_username(token_data[:username])
          return false unless account

          UrlValidator.url_allowed?(account, url)
        end

        def generate_feed_id(username, url, token)
          content = "#{username}:#{url}:#{token}"
          Digest::SHA256.hexdigest(content)[0..15]
        end

        def build_feed_data(name, url, token_data, strategy, identifiers)
          public_url = "/api/v1/feeds/#{identifiers[:feed_token]}"

          {
            id: identifiers[:feed_id],
            name: name,
            url: url,
            username: token_data[:username],
            strategy: strategy,
            public_url: public_url
          }
        end
      end
    end
  end
end
