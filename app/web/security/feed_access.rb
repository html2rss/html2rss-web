# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Centralizes account, token, and URL access checks for token-backed feed flows.
    module FeedAccess
      class << self
        # @param username [String, nil]
        # @return [Hash{Symbol=>Object}, nil]
        def account_for_username(username)
          AccountManager.get_account_by_username(username)
        end

        # @param token [String]
        # @return [Html2rss::Web::FeedToken]
        def authorize_feed_token!(token)
          feed_token = Auth.validate_and_decode_feed_token(token)
          raise Html2rss::Web::UnauthorizedError, 'Invalid token' unless feed_token

          account = account_for_username(feed_token.username)
          raise Html2rss::Web::UnauthorizedError, 'Account not found' unless account
          raise Html2rss::Web::ForbiddenError, 'Access Denied' unless UrlValidator.url_allowed?(account, feed_token.url)

          feed_token
        end

        # @param username [String, nil]
        # @param url [String]
        # @return [Boolean]
        def url_allowed_for_username?(username, url)
          account = account_for_username(username)
          return false unless account

          UrlValidator.url_allowed?(account, url)
        end
      end
    end
  end
end
