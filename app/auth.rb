# frozen_string_literal: true

require 'uri'
require 'openssl'
require 'base64'
require 'json'
require_relative 'local_config'
require_relative 'security_logger'
require_relative 'feed_token'
require_relative 'url_validator'
require_relative 'auth_utils'
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

        account = get_account(token)
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

      # @param token [String]
      # @return [Hash, nil]
      def get_account(token)
        AccountManager.get_account(token)
      end

      # @param account [Hash]
      # @param url [String]
      # @return [Boolean]
      def url_allowed?(account, url)
        UrlValidator.url_allowed?(account, url)
      end

      # @param username [String]
      # @param url [String]
      # @param token [String]
      # @return [String] 16-character hex feed ID
      def generate_feed_id(username, url, token)
        AuthUtils.generate_feed_id(username, url, token)
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

        url_allowed?(account, url)
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

      # @return [Array<Hash>]
      def accounts
        AccountManager.accounts
      end

      # @return [Array<Hash>]
      def load_accounts
        AccountManager.accounts
      end

      # @param username [String]
      # @return [Hash, nil]
      def get_account_by_username(username)
        AccountManager.get_account_by_username(username)
      end

      # @return [String, nil]
      def secret_key
        ENV.fetch('HTML2RSS_SECRET_KEY')
      end

      # @param url [String]
      # @param patterns [Array<String>]
      # @return [Boolean]
      def url_matches_patterns?(url, patterns)
        UrlValidator.url_matches_patterns?(url, patterns)
      end

      # @param url [String]
      # @param pattern [String]
      # @return [Boolean]
      def url_matches_pattern?(url, pattern)
        UrlValidator.url_matches_pattern?(url, pattern)
      end

      # Escapes XML special characters to prevent injection attacks
      # @param text [String]
      # @return [String]
      def sanitize_xml(text)
        AuthUtils.sanitize_xml(text)
      end

      # @param url [String]
      # @return [Boolean]
      def valid_url?(url)
        AuthUtils.valid_url?(url)
      end

      # @param username [String]
      # @return [Boolean]
      def valid_username?(username)
        AuthUtils.valid_username?(username)
      end
    end
  end
end
