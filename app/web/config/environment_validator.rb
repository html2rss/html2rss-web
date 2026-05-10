# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Environment validation for html2rss-web
    # Handles validation of environment variables and configuration
    module EnvironmentValidator # rubocop:disable Metrics/ModuleLength
      # rubocop:disable Metrics/ClassLength
      class << self
        ##
        # Validate required environment variables on startup
        # @return [void]
        def validate_environment!
          return if ENV['HTML2RSS_SECRET_KEY']

          if non_production?
            set_development_key
          else
            show_production_error
          end
        end

        ##
        # Validate production security configuration
        # @return [void]
        def validate_production_security!
          return if non_production?

          validate_secret_key!
          validate_account_configuration!
        end

        # @return [Boolean]
        def development? = ENV['RACK_ENV'] == 'development'
        # @return [Boolean]
        def test? = ENV['RACK_ENV'] == 'test'

        # @return [Boolean]
        def non_production?
          development? || test?
        end

        # @return [Boolean]
        def auto_source_enabled?
          Flags.auto_source_enabled?
        end

        private

        def set_development_key
          ENV['HTML2RSS_SECRET_KEY'] = 'development-default-key-not-for-production'
          log_development_default_secret_key_warning
          warn_lines(
            'WARNING: Using default secret key for development/testing only!',
            'Set HTML2RSS_SECRET_KEY environment variable for production use.'
          )
          nil
        end

        def show_production_error
          SecurityLogger.log_config_validation_failure('secret_key', 'Missing required secret key')
          warn_lines(*production_error_message.lines(chomp: true))
          exit 1
        end

        def production_error_message
          <<~ERROR
            ❌ ERROR: HTML2RSS_SECRET_KEY environment variable is not set!

            This application is designed to be used via Docker Compose only.
            Please read the project's README.md for setup instructions.

            To generate a secure secret key and start the application:
              1. Generate a secret key: openssl rand -hex 32
              2. Edit docker-compose.yml and replace 'your-generated-secret-key-here' with your key
              3. Start with: docker-compose up

            For more information, see: https://github.com/html2rss/html2rss-web#configuration
          ERROR
        end

        def validate_secret_key!
          secret = ENV.fetch('HTML2RSS_SECRET_KEY', nil)
          return unless secret == 'your-generated-secret-key-here' || secret.length < 32

          SecurityLogger.log_config_validation_failure('secret_key', 'Invalid or weak secret key')
          warn_lines(
            'CRITICAL: Invalid secret key for production deployment!',
            'Secret key must be at least 32 characters and not the default placeholder.',
            'Generate a secure key: openssl rand -hex 32'
          )
          exit 1
        end

        def validate_account_configuration!
          accounts = AccountManager.accounts
          validate_account_token_shapes!(accounts)
          validate_create_feed_token!(accounts)
          weak_tokens = accounts.select { |acc| acc[:token].length < 16 }
          return unless weak_tokens.any?

          handle_weak_account_tokens!(weak_tokens)
        end

        # @param accounts [Array<Hash{Symbol=>Object}>]
        # @return [void]
        def validate_account_token_shapes!(accounts)
          malformed_accounts = accounts.reject { |acc| acc[:token].is_a?(String) && !acc[:token].empty? }
          return unless malformed_accounts.any?

          handle_malformed_account_tokens!(malformed_accounts)
        end

        # @param accounts [Array<Hash{Symbol=>Object}>]
        # @return [void]
        def validate_create_feed_token!(accounts)
          return unless invalid_placeholder_create_feed_token?(accounts)

          SecurityLogger.log_config_validation_failure(
            'access_token',
            'Placeholder create-feed token is not allowed when auto source is enabled'
          )
          warn_lines(
            'CRITICAL: Placeholder create-feed token detected in production!',
            'Set HTML2RSS_ACCESS_TOKEN to a strong token before enabling automatic feed generation.'
          )
          exit 1
        end

        # @param accounts [Array<Hash{Symbol=>Object}>]
        # @return [Boolean]
        def invalid_placeholder_create_feed_token?(accounts)
          auto_source_enabled? && placeholder_create_feed_token?(accounts)
        end

        # @param accounts [Array<Hash{Symbol=>Object}>]
        # @return [Boolean]
        def placeholder_create_feed_token?(accounts)
          accounts.any? { |account| account[:token] == RuntimeEnv::ADMIN_ACCESS_TOKEN_PLACEHOLDER }
        end

        # @param lines [Array<String>]
        # @return [void]
        def warn_lines(*lines)
          lines.each { |line| Kernel.warn(line) }
          nil
        end

        # @return [void]
        def log_development_default_secret_key_warning
          SecurityLogger.log_config_validation_failure(
            'secret_key',
            'Using development default secret key',
            severity: :warn
          )
        end

        # @param weak_tokens [Array<Hash{Symbol=>String}>]
        # @return [void]
        def handle_weak_account_tokens!(weak_tokens)
          weak_usernames = weak_tokens.map { |acc| acc[:username] }.join(', ')
          SecurityLogger.log_config_validation_failure('account_tokens', "Weak tokens for users: #{weak_usernames}")
          warn_lines(
            'CRITICAL: Weak authentication tokens detected in production!',
            'All tokens must be at least 16 characters long.',
            "Weak tokens found for users: #{weak_usernames}"
          )
          exit 1
        end

        # @param malformed_accounts [Array<Hash{Symbol=>Object}>]
        # @return [void]
        def handle_malformed_account_tokens!(malformed_accounts)
          malformed_usernames = malformed_accounts.map { |acc| acc[:username] || '(unknown)' }.join(', ')
          SecurityLogger.log_config_validation_failure('account_tokens',
                                                       "Invalid token configuration for users: #{malformed_usernames}")
          warn_lines(
            'CRITICAL: Invalid account token configuration detected in production!',
            'Each account token must be a non-empty string.',
            "Invalid token configuration found for users: #{malformed_usernames}"
          )
          exit 1
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
