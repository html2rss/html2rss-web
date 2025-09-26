# frozen_string_literal: true

require 'openssl'
require_relative 'security_logger'
require_relative 'feed_token'
require_relative 'url_validator'
require_relative 'account_manager'

module Html2rss
  ##
  # Web application modules for html2rss
  module Web
    # Authentication system
    module Auth
      class << self
        # @param request [Rack::Request]
        # @return [Hash, nil] account data if authenticated
        def authenticate(request)
          token = extract_token(request)
          return audit_auth(request, nil, 'missing_token') unless token

          account = AccountManager.get_account(token)
          audit_auth(request, account, 'invalid_token')
        end

        # @param username [String]
        # @param url [String]
        # @param expires_in [Integer] seconds (default: 10 years)
        # @return [String] HMAC-signed compressed feed token
        def generate_feed_token(username, url, expires_in: Html2rss::Web::DEFAULT_EXPIRY)
          token = FeedToken.create_with_validation(
            username: username,
            url: url,
            expires_in: expires_in,
            secret_key: secret_key
          )
          token&.encode
        end

        # @param feed_token [String]
        # @param url [String]
        # @return [Hash, nil]
        def validate_feed_token(feed_token, url)
          with_validated_token(feed_token, url) do |token|
            AccountManager.get_account_by_username(token.username)
          end
        end

        # @param feed_token [String]
        # @param url [String]
        # @return [Boolean]
        def feed_url_allowed?(feed_token, url)
          account = validate_feed_token(feed_token, url)
          return false unless account

          UrlValidator.url_allowed?(account, url)
        end

        # @param token [String]
        # @return [Html2rss::Web::FeedToken, nil]
        def validate_and_decode_feed_token(token)
          decoded = FeedToken.decode(token)
          return unless decoded

          with_validated_token(token, decoded.url) { |validated| validated }
        end

        private

        # @param request [Rack::Request]
        # @param reason [String]
        # @return [nil]
        def log_auth_failure(request, reason)
          SecurityLogger.log_auth_failure(request.ip, request.user_agent, reason)
          nil
        end

        # @param account [Hash]
        # @param request [Rack::Request]
        # @return [Hash]
        def log_auth_success(account, request)
          SecurityLogger.log_auth_success(account[:username], request.ip)
          account
        end

        # @param request [Rack::Request]
        # @return [String, nil]
        def extract_token(request)
          auth_header = request.env['HTTP_AUTHORIZATION']
          return unless auth_header&.start_with?('Bearer ')

          token = auth_header.delete_prefix('Bearer ')
          return nil if token.empty? || token.length > 1024

          token
        end

        def audit_auth(request, account, failure_reason)
          return log_auth_success(account, request) if account

          log_auth_failure(request, failure_reason)
        end

        def with_validated_token(feed_token, url)
          return nil unless feed_token && url

          token = FeedToken.validate_and_decode(feed_token, url, secret_key)
          SecurityLogger.log_token_usage(feed_token, url, !token.nil?)
          return nil unless token

          yield token
        end

        # @return [String]
        def secret_key
          ENV.fetch('HTML2RSS_SECRET_KEY')
        end
      end
    end
  end
end
