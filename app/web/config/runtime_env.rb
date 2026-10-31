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
      BOOT_METADATA_KEYS = %w[
        BUILD_TAG GIT_SHA RACK_ENV PORT WEB_CONCURRENCY REQUEST_TIMEOUT_SECONDS
      ].freeze
      MISSING = Object.new.freeze
      private_constant :MISSING
      # rubocop:disable ThreadSafety/ClassInstanceVariable
      @values = {}.freeze

      class << self
        # @return [void]
        def capture!
          @values = tracked_env_values.freeze
          scrub_sensitive_env!
          nil
        end

        # @return [void]
        def reset!
          @values = {}.freeze
        end

        # Stripped +HEALTH_CHECK_TOKEN+, or nil when blank.
        # The placeholder is returned only when it is the configured value.
        #
        # @return [String, nil]
        def health_check_token = fetch('HEALTH_CHECK_TOKEN', '').to_s.strip.then { it unless it.empty? }

        # Credential for private +/api/v1/health+.
        # Blank and {HEALTH_CHECK_TOKEN_PLACEHOLDER} are rejected.
        #
        # @return [String, nil]
        def private_probe_token = health_check_token.then { it unless it == HEALTH_CHECK_TOKEN_PLACEHOLDER }

        # @return [String]
        def admin_access_token = access_token.to_s.strip.then { it.empty? ? ADMIN_ACCESS_TOKEN_PLACEHOLDER : it }

        # @return [Boolean]
        def sentry_enabled? = !sentry_dsn.to_s.strip.empty?

        private

        # Defines a public reader for one environment key.
        #
        # @param name [Symbol] reader name.
        # @param key [String] environment variable.
        # @param default [Object] value when unset; omit to raise +KeyError+.
        # @param coerce [Symbol, nil] conversion sent to the raw value (e.g. +:to_i+).
        # @return [Symbol]
        def reader(name, key, default = MISSING, coerce: nil)
          define_singleton_method(name) do
            value = fetch(key, default)
            coerce ? value.public_send(coerce) : value
          end
        end

        # @param key [String]
        # @param default [Object]
        # @return [Object]
        def fetch(key, default)
          return ENV.fetch(key) if ENV.key?(key)
          return @values.fetch(key) if @values.key?(key)
          # rubocop:enable ThreadSafety/ClassInstanceVariable
          return default unless default.equal?(MISSING)

          raise KeyError, "key not found: #{key}"
        end

        # @return [Hash{String=>String}]
        def tracked_env_values
          ENV.to_h.slice(*SENSITIVE_KEYS, *BOOT_METADATA_KEYS)
        end

        # @return [void]
        def scrub_sensitive_env!
          return nil if rack_env == 'test'

          SENSITIVE_KEYS.each { |key| ENV.delete(key) }
          nil
        end
      end

      reader :secret_key, 'HTML2RSS_SECRET_KEY'
      reader :access_token, 'HTML2RSS_ACCESS_TOKEN', ''
      reader :sentry_dsn, 'SENTRY_DSN', nil
      reader :build_tag, 'BUILD_TAG', 'unknown'
      reader :git_sha, 'GIT_SHA', 'unknown'
      reader :rack_env, 'RACK_ENV', 'development'
      reader :port, 'PORT', 4000, coerce: :to_i
      reader :web_concurrency, 'WEB_CONCURRENCY', 2, coerce: :to_i
      reader :request_timeout_seconds, 'REQUEST_TIMEOUT_SECONDS', 55.0, coerce: :to_f
    end
  end
end
