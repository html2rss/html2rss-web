# frozen_string_literal: true

require 'uri'
require 'digest'
require 'openssl'
require 'base64'
require 'json'
require 'cgi'
require_relative 'local_config'
require_relative 'security_logger'
require_relative 'feed_token'

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
        return nil unless token && token_index.key?(token)

        token_index[token]
      end

      # @return [Hash] token to account mapping
      def token_index
        @token_index ||= build_token_index # rubocop:disable ThreadSafety/ClassInstanceVariable
      end

      # @return [Hash]
      def build_token_index
        accounts.each_with_object({}) { |account, hash| hash[account[:token]] = account }
      end

      # @param account [Hash]
      # @param url [String]
      # @return [Boolean]
      def url_allowed?(account, url)
        return false unless account && url

        allowed_urls = account[:allowed_urls] || []
        return true if allowed_urls.empty? # No restrictions
        return true if allowed_urls.include?('*') # Full access

        url_matches_patterns?(url, allowed_urls)
      end

      # @param username [String]
      # @param url [String]
      # @param token [String]
      # @return [String] 16-character hex feed ID
      def generate_feed_id(username, url, token)
        content = "#{username}:#{url}:#{token}"
        Digest::SHA256.hexdigest(content)[0..15]
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

        get_account_by_username(token.username)
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
        load_accounts
      end

      # @param username [String]
      # @return [Hash, nil]
      def get_account_by_username(username)
        return nil unless username

        accounts.find { |account| account[:username] == username }
      end

      # @return [Array<Hash>]
      def load_accounts
        auth_config = LocalConfig.global[:auth]
        return [] unless auth_config&.dig(:accounts)

        auth_config[:accounts].map do |account|
          {
            username: account[:username].to_s,
            token: account[:token].to_s,
            allowed_urls: Array(account[:allowed_urls]).map(&:to_s)
          }
        end
      end

      # @return [String, nil]
      def secret_key
        ENV.fetch('HTML2RSS_SECRET_KEY')
      end

      # @param url [String]
      # @param patterns [Array<String>]
      # @return [Boolean]
      def url_matches_patterns?(url, patterns)
        patterns.any? { |pattern| url_matches_pattern?(url, pattern) }
      rescue RegexpError
        false
      end

      # @param url [String]
      # @param pattern [String]
      # @return [Boolean]
      def url_matches_pattern?(url, pattern)
        if pattern.include?('*')
          escaped_pattern = Regexp.escape(pattern).gsub('\\*', '.*')
          url.match?(/\A#{escaped_pattern}\z/)
        else
          # Exact match for non-wildcard patterns
          url == pattern
        end
      end

      # Escapes XML special characters to prevent injection attacks
      # @param text [String]
      # @return [String]
      def sanitize_xml(text)
        return '' unless text

        CGI.escapeHTML(text.to_s)
      end

      # @param url [String]
      # @return [Boolean]
      def valid_url?(url)
        FeedToken.valid_url?(url)
      end

      # @param username [String]
      # @return [Boolean]
      def valid_username?(username)
        FeedToken.valid_username?(username)
      end
    end
  end
end
