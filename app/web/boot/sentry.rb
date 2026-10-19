# frozen_string_literal: true

module Html2rss
  module Web
    module Boot
      ##
      # Configures Sentry boot-time exception capture.
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
            apply_scope_tags!
          end

          # @param config [Object]
          # @return [void]
          def apply_settings(config)
            config.dsn = RuntimeEnv.sentry_dsn
            config.environment = RuntimeEnv.rack_env
            config.send_default_pii = false
            config.release = release_name
            config.traces_sample_rate = 0
            config.profiles_sample_rate = 0
            drop_sdk_logs_and_metrics!(config)
          end

          # sentry-ruby 7 enables structured logs and metrics by default.
          # Keep the web process exception-only: drop SDK log and metric intake.
          #
          # @param config [Object]
          # @return [void]
          def drop_sdk_logs_and_metrics!(config)
            config.before_send_log = ->(_log) {}
            config.before_send_metric = ->(_metric) {} if config.respond_to?(:before_send_metric=)
            nil
          end

          # @return [String]
          def release_name
            "#{RuntimeEnv.build_tag}+#{RuntimeEnv.git_sha}"
          end

          # @return [void]
          def apply_scope_tags!
            return unless defined?(::Sentry) && ::Sentry.respond_to?(:configure_scope)

            ::Sentry.configure_scope do |scope|
              scope.set_tags(
                release: release_name,
                environment: RuntimeEnv.rack_env
              )
            end
          rescue StandardError
            nil
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
