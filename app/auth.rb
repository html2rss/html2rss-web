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
      module_function

      # @param request [Rack::Request]
      # @return [Hash, nil] account data if authenticated
      def authenticate(request)
        token = extract_token(request)
        return log_auth_failure(request, 'missing_token') unless token

        account = AccountManager.get_account(token)
        return log_auth_success(account, request) if account

        log_auth_failure(request, 'invalid_token')
      end

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
        return nil unless feed_token && url

        token = FeedToken.validate_and_decode(feed_token, url, secret_key)
        valid = !token.nil?
        SecurityLogger.log_token_usage(feed_token, url, valid)

        return nil unless valid

        AccountManager.get_account_by_username(token.username)
      end

      # @param feed_token [String]
      # @param url [String]
      # @return [Boolean]
      def feed_url_allowed?(feed_token, url)
        account = validate_feed_token(feed_token, url)
        return false unless account

        UrlValidator.url_allowed?(account, url)
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

      # @return [String, nil]
      def secret_key
        ENV.fetch('HTML2RSS_SECRET_KEY')
      end
    end
  end
end
