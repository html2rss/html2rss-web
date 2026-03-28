# frozen_string_literal: true

module Html2rss
  module Web
    module Boot
      ##
      # Configures Sentry boot-time error and structured log capture.
      module Sentry
        class << self
          # @return [void]
          def configure!
            return unless configure?

            Bundler.require(:sentry)
            require 'sentry-ruby'
            initialize_sentry!
          end

          private

          # @return [Boolean]
          def configure?
            RuntimeEnv.sentry_enabled? && !sentry_initialized?
          end

          # @return [void]
          def initialize_sentry!
            ::Sentry.init do |config|
              apply_settings(config)
            end
          end

          # @param config [Object]
          # @return [void]
          def apply_settings(config)
            config.dsn = RuntimeEnv.sentry_dsn
            config.environment = RuntimeEnv.rack_env
            config.enable_logs = RuntimeEnv.sentry_logs_enabled?
            config.send_default_pii = false
            config.release = release_name
          end

          # @return [String]
          def release_name
            "#{RuntimeEnv.build_tag}+#{RuntimeEnv.git_sha}"
          end

          # @return [Boolean]
          def sentry_initialized?
            defined?(::Sentry) && ::Sentry.respond_to?(:initialized?) && ::Sentry.initialized?
          end
        end
      end
    end
  end
end
