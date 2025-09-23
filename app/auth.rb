# frozen_string_literal: true

require 'uri'
require 'digest'
require 'openssl'
require 'base64'
require 'json'
require 'cgi'
require_relative 'local_config'
require_relative 'security_logger'

module Html2rss
  ##
  # Web application modules for html2rss
  module Web
    ##
    # Unified authentication system for html2rss-web
    module Auth
      # Default token expiry: 10 years in seconds
      DEFAULT_TOKEN_EXPIRY = 315_360_000

      module_function

      ##
      # Authenticate a request and return account data if valid
      # @param request [Rack::Request] request object
      # @return [Hash, nil] account data if authenticated
      def authenticate(request)
        token = extract_token(request)
        return log_auth_failure(request, 'missing_token') unless token

        account = get_account(token)
        return log_auth_success(account, request) if account

        log_auth_failure(request, 'invalid_token')
      end

      ##
      # Log auth failure and return nil
      # @param request [Rack::Request] request object
      # @param reason [String] failure reason
      # @return [nil]
      def log_auth_failure(request, reason)
        SecurityLogger.log_auth_failure(request.ip, request.user_agent, reason)
        nil
      end

      ##
      # Log auth success and return account
      # @param account [Hash] account data
      # @param request [Rack::Request] request object
      # @return [Hash] account data
      def log_auth_success(account, request)
        SecurityLogger.log_auth_success(account[:username], request.ip)
        account
      end

      ##
      # Get account data by token
      # @param token [String] authentication token
      # @return [Hash, nil] account data if found
      def get_account(token)
        return nil unless token && token_index.key?(token)

        token_index[token]
      end

      ##
      # Get token index for O(1) lookups
      # @return [Hash] token to account mapping
      def token_index
        @token_index ||= build_token_index # rubocop:disable ThreadSafety/ClassInstanceVariable
      end

      ##
      # Build token index in a thread-safe manner
      # @return [Hash] token to account mapping
      def build_token_index
        accounts.each_with_object({}) { |account, hash| hash[account[:token]] = account }
      end

      ##
      # Check if a URL is allowed for the given account
      # @param account [Hash] account data
      # @param url [String] URL to check
      # @return [Boolean] true if URL is allowed
      def url_allowed?(account, url)
        return false unless account && url

        allowed_urls = account[:allowed_urls] || []
        return true if allowed_urls.empty? # No restrictions
        return true if allowed_urls.include?('*') # Full access

        url_matches_patterns?(url, allowed_urls)
      end

      ##
      # Generate a stable feed ID based on username, URL, and token
      # @param username [String] account username
      # @param url [String] source URL
      # @param token [String] authentication token
      # @return [String] 16-character hex feed ID
      def generate_feed_id(username, url, token)
        content = "#{username}:#{url}:#{token}"
        Digest::SHA256.hexdigest(content)[0..15]
      end

      ##
      # Generate a secure feed-specific token for public access
      # @param username [String] account username
      # @param url [String] source URL
      # @param expires_in [Integer] token expiration in seconds (default: 10 years)
      # @return [String] HMAC-signed feed token
      def generate_feed_token(username, url, expires_in: DEFAULT_TOKEN_EXPIRY)
        secret_key = self.secret_key
        return nil unless secret_key
        return nil unless valid_username?(username) && valid_url?(url)

        payload = create_token_payload(username, url, expires_in)
        signature = create_hmac_signature(secret_key, payload)
        token_data = { payload: payload, signature: signature }

        Base64.urlsafe_encode64(token_data.to_json)
      end

      def create_token_payload(username, url, expires_in)
        {
          username: username,
          url: url,
          expires_at: Time.now.to_i + expires_in.to_i
        }
      end

      def create_hmac_signature(secret_key, payload)
        OpenSSL::HMAC.hexdigest('SHA256', secret_key, payload.to_json)
      end

      ##
      # Validate a feed token and return account data if valid
      # @param feed_token [String] feed token to validate
      # @param url [String] URL being accessed
      # @return [Hash, nil] account data if valid
      def validate_feed_token(feed_token, url)
        return nil unless feed_token && url

        token_data = decode_feed_token(feed_token)
        valid = token_data && verify_token_signature(token_data) && token_valid?(token_data, url)

        SecurityLogger.log_token_usage(feed_token, url, valid)

        return nil unless valid

        get_account_by_username(token_data[:payload][:username])
      rescue JSON::ParserError, ArgumentError
        SecurityLogger.log_token_usage(feed_token, url, false)
        nil
      end

      def decode_feed_token(feed_token)
        token_data = JSON.parse(Base64.urlsafe_decode64(feed_token), symbolize_names: true)
        return nil unless token_data[:payload] && token_data[:signature]

        token_data
      end

      def verify_token_signature(token_data)
        secret_key = self.secret_key
        return false unless secret_key

        expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret_key, token_data[:payload].to_json)
        secure_compare(token_data[:signature], expected_signature)
      end

      ##
      # Constant-time string comparison to prevent timing attacks
      # @param first_string [String] first string
      # @param second_string [String] second string
      # @return [Boolean] true if strings are equal
      def secure_compare(first_string, second_string)
        return false unless first_string && second_string
        return false unless first_string.bytesize == second_string.bytesize

        result = 0
        first_string.bytes.zip(second_string.bytes) { |x, y| result |= x ^ y }
        result.zero?
      end

      def token_valid?(token_data, url)
        payload = token_data[:payload]
        return false if Time.now.to_i > payload[:expires_at]
        return false unless payload[:url] == url

        true
      end

      ##
      # Extract feed token from URL query parameters
      # @param url [String] full URL with query parameters
      # @return [String, nil] feed token if found
      def extract_feed_token_from_url(url)
        URI.parse(url).then { |uri| CGI.parse(uri.query || '')['token']&.first }
      rescue StandardError
        nil
      end

      ##
      # Check if a feed URL is allowed for the given feed token
      # @param feed_token [String] feed token
      # @param url [String] URL to check
      # @return [Boolean] true if URL is allowed
      def feed_url_allowed?(feed_token, url)
        account = validate_feed_token(feed_token, url)
        return false unless account

        url_allowed?(account, url)
      end

      ##
      # Extract token from request (Authorization header only)
      # @param request [Rack::Request] request object
      # @return [String, nil] token if found
      def extract_token(request)
        auth_header = request.env['HTTP_AUTHORIZATION']
        return unless auth_header&.start_with?('Bearer ')

        token = auth_header.delete_prefix('Bearer ')
        return nil if token.empty? || token.length > 1024

        token
      end

      ##
      # Get all configured accounts
      # @return [Array<Hash>] array of account hashes
      def accounts
        load_accounts
      end

      ##
      # Get account by username
      # @param username [String] username to find
      # @return [Hash, nil] account data if found
      def get_account_by_username(username)
        return nil unless username

        accounts.find { |account| account[:username] == username }
      end

      ##
      # Load accounts from config
      # @return [Array<Hash>] array of account hashes
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

      ##
      # Get the secret key for HMAC signing
      # @return [String, nil] secret key if configured
      def secret_key
        ENV.fetch('HTML2RSS_SECRET_KEY')
      end

      ##
      # Check if URL matches any of the allowed patterns
      # @param url [String] URL to check
      # @param patterns [Array<String>] allowed URL patterns
      # @return [Boolean] true if URL matches any pattern
      def url_matches_patterns?(url, patterns)
        patterns.any? { |pattern| url_matches_pattern?(url, pattern) }
      rescue RegexpError
        false
      end

      ##
      # Check if URL matches a single pattern
      # @param url [String] URL to check
      # @param pattern [String] pattern to match against
      # @return [Boolean] true if URL matches pattern
      def url_matches_pattern?(url, pattern)
        if pattern.include?('*')
          escaped_pattern = Regexp.escape(pattern).gsub('\\*', '.*')
          url.match?(/\A#{escaped_pattern}\z/)
        else
          # Exact match for non-wildcard patterns
          url == pattern
        end
      end

      ##
      # Sanitize text for safe inclusion in XML output
      # Escapes XML special characters to prevent injection attacks
      # @param text [String] text to sanitize
      # @return [String] sanitized text safe for XML
      def sanitize_xml(text)
        return '' unless text

        CGI.escapeHTML(text.to_s)
      end

      ##
      # Validate URL format and scheme
      # @param url [String] URL to validate
      # @return [Boolean] true if URL is valid
      def valid_url?(url)
        return false unless url.is_a?(String) && !url.empty? && url.length <= 2048

        uri = URI.parse(url)
        uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      rescue StandardError
        false
      end

      ##
      # Validate username format and length
      # @param username [String] username to validate
      # @return [Boolean] true if username is valid
      def valid_username?(username)
        return false unless username.is_a?(String)
        return false if username.empty? || username.length > 100
        return false unless username.match?(/\A[a-zA-Z0-9_-]+\z/)

        true
      end
    end
  end
end
