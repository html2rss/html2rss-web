# frozen_string_literal: true

module Html2rss
  module Web
    module Boot
      ##
      # Applies boot-time runtime configuration outside the Roda class body.
      module Setup
        RACK_TIMEOUT_BUFFER_SECONDS = 5

        class << self
          # @return [Boolean]
          def sentry_enabled?
            RuntimeEnv.sentry_enabled?
          end

          # Validates environment configuration and wires the request service.
          #
          # @return [void]
          def call!
            validate_environment!
            capture_runtime_env!
            configure_sentry!
            configure_request_service!
            configure_runtime_logging!
            log_startup!
          end

          private

          # @return [void]
          def validate_environment!
            EnvironmentValidator.validate_environment!
            EnvironmentValidator.validate_production_security!
            Flags.validate!
          end

          # @return [void]
          def capture_runtime_env!
            RuntimeEnv.capture!
          end

          # @return [void]
          def configure_sentry!
            Sentry.configure!
          end

          # @return [void]
          def configure_request_service!
            return unless defined?(Rack::Timeout)
            return unless Rack::Timeout.respond_to?(:service_timeout=)

            Rack::Timeout.service_timeout =
              Html2rss::RequestService::Policy::DEFAULTS[:total_timeout_seconds] +
              RACK_TIMEOUT_BUFFER_SECONDS
          end

          # @return [void]
          def configure_runtime_logging!
            return unless defined?(Rack::Timeout::Logger)

            Rack::Timeout::Logger.logger = AppLogger.logger
          end

          # @return [void]
          def log_startup!
            AppLogger.logger.info(
              {
                component: 'boot',
                event_name: 'app.start',
                build_tag: RuntimeEnv.build_tag,
                git_sha: RuntimeEnv.git_sha,
                sentry_enabled: RuntimeEnv.sentry_enabled?
              }.to_json
            )
          end
        end
      end
    end
  end
end
