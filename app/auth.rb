# frozen_string_literal: true

require 'uri'
require 'digest'
require 'openssl'
require 'base64'
require 'json'
require 'cgi'
require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Unified authentication system for html2rss-web
    module Auth
      # Default token expiry: 10 years in seconds
      DEFAULT_TOKEN_EXPIRY = 315_360_000

      module_function

      ##
      # Authenticate a request and return account data if valid
      # @param request [Roda::Request] the request object
      # @return [Hash, nil] account data if authenticated, nil otherwise
      def authenticate(request)
        token = extract_token(request)
        return nil unless token

        get_account(token)
      end

      ##
      # Get account data by token
      # @param token [String] the authentication token
      # @return [Hash, nil] account data if found, nil otherwise
      def get_account(token)
        return nil unless token

        accounts.find { |account| account[:token] == token }
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
      # @param feed_token [String] the feed token to validate
      # @param url [String] the URL being accessed
      # @return [Hash, nil] account data if valid, nil otherwise
      def validate_feed_token(feed_token, url)
        return nil unless feed_token && url

        token_data = decode_feed_token(feed_token)
        return nil unless token_data && verify_token_signature(token_data) && token_valid?(token_data, url)

        get_account_by_username(token_data[:payload][:username])
      rescue StandardError
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
        token_data[:signature] == expected_signature
      end

      def token_valid?(token_data, url)
        payload = token_data[:payload]
        return false if Time.now.to_i > payload[:expires_at]
        return false unless payload[:url] == url

        true
      end

      ##
      # Extract feed token from URL query parameters
      # @param url [String] the full URL with query parameters
      # @return [String, nil] feed token if found, nil otherwise
      def extract_feed_token_from_url(url)
        URI.parse(url).then { |uri| URI.decode_www_form(uri.query || '').to_h['token'] }
      rescue StandardError
        nil
      end

      ##
      # Check if a feed URL is allowed for the given feed token
      # @param feed_token [String] the feed token
      # @param url [String] the URL to check
      # @return [Boolean] true if URL is allowed
      def feed_url_allowed?(feed_token, url)
        account = validate_feed_token(feed_token, url)
        return false unless account

        url_allowed?(account, url)
      end

      ##
      # Extract token from request (Authorization header only)
      # @param request [Roda::Request] the request object
      # @return [String, nil] token if found, nil otherwise
      def extract_token(request)
        auth_header = request.env['HTTP_AUTHORIZATION']
        return unless auth_header&.start_with?('Bearer ')

        auth_header.delete_prefix('Bearer ')
      end

      ##
      # Get all configured accounts
      # @return [Array<Hash>] array of account hashes
      def accounts
        load_accounts
      end

      ##
      # Reload accounts from config (useful for development)
      def reload_accounts!
        accounts
      end

      ##
      # Get account by username
      # @param username [String] the username to find
      # @return [Hash, nil] account data if found, nil otherwise
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
      # @return [String, nil] secret key if configured, nil otherwise
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
          url.include?(pattern)
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
      # Validate URL format and scheme using Html2rss::Url.for_channel
      # @param url [String] URL to validate
      # @return [Boolean] true if URL is valid and allowed, false otherwise
      def valid_url?(url)
        return false unless url.is_a?(String) && !url.empty? && url.length <= 2048

        !Html2rss::Url.for_channel(url).nil?
      rescue StandardError
        false
      end
    end
  end
end
