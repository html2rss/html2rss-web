# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Captures boot-time environment configuration and scrubs selected secrets
    # from the process environment after validation.
    module RuntimeEnv
      SENSITIVE_KEYS = %w[HTML2RSS_SECRET_KEY HEALTH_CHECK_TOKEN SENTRY_DSN].freeze
      BOOT_METADATA_KEYS = %w[BUILD_TAG GIT_SHA RACK_ENV].freeze

      class << self
        # @return [void]
        def capture!
          @values = tracked_env_values.freeze # rubocop:disable ThreadSafety/ClassInstanceVariable
          scrub_sensitive_env!
          nil
        end

        # @return [void]
        def reset!
          @values = nil # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # @return [String]
        def secret_key
          fetch('HTML2RSS_SECRET_KEY')
        end

        # @return [String]
        def health_check_token
          fetch('HEALTH_CHECK_TOKEN', '')
        end

        # @return [String, nil]
        def sentry_dsn
          fetch('SENTRY_DSN', nil)
        end

        # @return [Boolean]
        def sentry_enabled?
          !sentry_dsn.to_s.strip.empty?
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

          values = @values || {} # rubocop:disable ThreadSafety/ClassInstanceVariable
          return values.fetch(key) if values.key?(key)
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
      end
    end
  end
end
