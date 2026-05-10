# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Captures boot-time environment configuration and scrubs selected secrets
    # from the process environment after validation.
    module RuntimeEnv
      ADMIN_ACCESS_TOKEN_PLACEHOLDER = 'CHANGE_ME_ADMIN_TOKEN'
      HEALTH_CHECK_TOKEN_PLACEHOLDER = 'CHANGE_ME_HEALTH_CHECK_TOKEN'
      SENSITIVE_KEYS = %w[HTML2RSS_SECRET_KEY HTML2RSS_ACCESS_TOKEN HEALTH_CHECK_TOKEN SENTRY_DSN].freeze
      BOOT_METADATA_KEYS = %w[BUILD_TAG GIT_SHA RACK_ENV SENTRY_ENABLE_LOGS].freeze
      @mutex = Mutex.new
      @values = nil

      class << self
        # @return [void]
        def capture!
          @mutex.synchronize { @values = tracked_env_values.freeze }
          scrub_sensitive_env!
          nil
        end

        # @return [void]
        def reset!
          @mutex.synchronize { @values = nil }
        end

        # @return [String]
        def secret_key
          fetch('HTML2RSS_SECRET_KEY')
        end

        # @return [String]
        def health_check_token
          fetch('HEALTH_CHECK_TOKEN', '')
        end

        # @return [String]
        def access_token
          fetch('HTML2RSS_ACCESS_TOKEN', '')
        end

        # @return [String]
        def admin_access_token
          token = access_token.to_s.strip
          token.empty? ? ADMIN_ACCESS_TOKEN_PLACEHOLDER : token
        end

        # @return [String, nil]
        def sentry_dsn
          fetch('SENTRY_DSN', nil)
        end

        # @return [Boolean]
        def sentry_enabled?
          !sentry_dsn.to_s.strip.empty?
        end

        # @return [Boolean]
        def sentry_logs_enabled?
          parse_boolean(fetch('SENTRY_ENABLE_LOGS', 'false'), default: false)
        end

        # @return [String]
        def build_tag
          fetch('BUILD_TAG', 'unknown')
        end

        # @return [String]
        def git_sha
          fetch('GIT_SHA', 'unknown')
        end

        # @return [String]
        def rack_env
          fetch('RACK_ENV', ENV.fetch('RACK_ENV', 'development'))
        end

        private

        # @param key [String]
        # @param default [Object]
        # @return [Object]
        def fetch(key, default = :__missing__)
          return ENV.fetch(key) if ENV.key?(key)

          current_values = @mutex.synchronize { @values || {} }
          return current_values.fetch(key) if current_values.key?(key)
          return default unless default == :__missing__

          raise KeyError, "key not found: #{key}"
        end

        # @return [Hash{String=>String}]
        def tracked_env_values
          (SENSITIVE_KEYS + BOOT_METADATA_KEYS).each_with_object({}) do |key, memo|
            memo[key] = ENV[key] if ENV.key?(key)
          end
        end

        # @return [void]
        def scrub_sensitive_env!
          return nil if rack_env == 'test'

          SENSITIVE_KEYS.each { |key| ENV.delete(key) }
          nil
        end

        # @param value [Object]
        # @param default [Boolean]
        # @return [Boolean]
        def parse_boolean(value, default:)
          normalized = value.to_s.strip.downcase
          return true if normalized == 'true'
          return false if normalized == 'false'
          return default if normalized.empty?

          raise ArgumentError, "Malformed env 'SENTRY_ENABLE_LOGS': expected true/false, got '#{value}'"
        end
      end
    end
  end
end
