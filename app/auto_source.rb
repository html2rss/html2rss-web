# frozen_string_literal: true

require 'digest'
require_relative 'account_manager'
require_relative 'auth'
require_relative 'feed_generator'
require_relative 'url_validator'

module Html2rss
  module Web
    ##
    # Stateless helpers for auto-source feed creation and rendering.
    #
    # Responsibilities stay small: validate access, create stable identifiers,
    # and delegate actual scraping/rendering to feed services.
    module AutoSource
      class << self
        # @return [Boolean]
        def enabled?
          EnvironmentValidator.auto_source_enabled?
        end

        # Builds stable feed metadata for an authenticated account.
        #
        # @param name [String, nil]
        # @param url [String]
        # @param token_data [Hash{Symbol=>Object}] authenticated token/account data.
        # @param strategy [String]
        # @return [Hash{Symbol=>Object}, nil] feed metadata when allowed.
        # @option return [String] :id stable feed identifier.
        # @option return [String, nil] :name optional feed name.
        # @option return [String] :url source URL.
        # @option return [String] :username account username.
        # @option return [String] :strategy strategy identifier.
        # @option return [String] :public_url API URL containing signed token.
        def create_stable_feed(name, url, token_data, strategy = 'ssrf_filter')
          return nil unless url_allowed_for_token?(token_data, url)

          feed_id = generate_feed_id(token_data[:username], url, token_data[:token])
          feed_token = Auth.generate_feed_token(token_data[:username], url, strategy: strategy)
          return nil unless feed_token

          identifiers = { feed_id: feed_id, feed_token: feed_token }

          build_feed_data(name, url, token_data, strategy, identifiers)
        end

        # Reconstructs minimal feed context from stable id + token data.
        #
        # @param feed_id [String]
        # @param token_data [Hash{Symbol=>Object}, nil]
        # @return [Hash{Symbol=>Object}, nil]
        # @option return [String] :id stable feed identifier.
        # @option return [String, nil] :url source URL placeholder.
        # @option return [String] :username account username.
        # @option return [String] :strategy strategy identifier.
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

        # @param url [String]
        # @param strategy [String]
        # @return [Object] raw feed object from selected strategy.
        def generate_feed_object(url, strategy = 'ssrf_filter')
          FeedGenerator.call_strategy(url, strategy)
        end

        # @param url [String]
        # @param strategy [String]
        # @return [String] rendered RSS/XML content.
        def generate_feed_content(url, strategy = 'ssrf_filter')
          feed_content = FeedGenerator.call_strategy(url, strategy)
          FeedGenerator.process_feed_content(url, strategy, feed_content)
        end

        private

        # @param token_data [Hash{Symbol=>Object}]
        # @param url [String]
        # @return [Boolean]
        def url_allowed_for_token?(token_data, url)
          account = AccountManager.get_account_by_username(token_data[:username])
          return false unless account

          UrlValidator.url_allowed?(account, url)
        end

        # @param username [String]
        # @param url [String]
        # @param token [String]
        # @return [String] deterministic short feed id.
        def generate_feed_id(username, url, token)
          content = "#{username}:#{url}:#{token}"
          Digest::SHA256.hexdigest(content)[0..15]
        end

        # @param name [String, nil]
        # @param url [String]
        # @param token_data [Hash{Symbol=>Object}]
        # @param strategy [String]
        # @param identifiers [Hash{Symbol=>String}]
        # @return [Hash{Symbol=>Object}]
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
