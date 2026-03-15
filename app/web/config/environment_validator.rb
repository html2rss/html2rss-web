# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Environment validation for html2rss-web
    # Handles validation of environment variables and configuration
    module EnvironmentValidator
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
          puts '⚠️  WARNING: Using default secret key for development/testing only!'
          puts '   Set HTML2RSS_SECRET_KEY environment variable for production use.'
        end

        def show_production_error
          puts production_error_message
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
          puts '❌ CRITICAL: Invalid secret key for production deployment!'
          puts '   Secret key must be at least 32 characters and not the default placeholder.'
          puts '   Generate a secure key: openssl rand -hex 32'
          exit 1
        end

        def validate_account_configuration!
          accounts = AccountManager.accounts
          weak_tokens = accounts.select { |acc| acc[:token].length < 16 }
          return unless weak_tokens.any?

          weak_usernames = weak_tokens.map { |acc| acc[:username] }.join(', ')
          SecurityLogger.log_config_validation_failure('account_tokens', "Weak tokens for users: #{weak_usernames}")
          puts '❌ CRITICAL: Weak authentication tokens detected in production!'
          puts '   All tokens must be at least 16 characters long.'
          puts "   Weak tokens found for users: #{weak_usernames}"
          exit 1
        end
      end
    end
  end
end
