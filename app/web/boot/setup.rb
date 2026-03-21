# frozen_string_literal: true

module Html2rss
  module Web
    module Boot
      ##
      # Applies boot-time runtime configuration outside the Roda class body.
      module Setup
        class << self
          # Validates environment configuration and wires the request service.
          #
          # @return [void]
          def call!
            validate_environment!
            configure_request_service!
            configure_runtime_logging!
          end

          private

          # @return [void]
          def validate_environment!
            EnvironmentValidator.validate_environment!
            EnvironmentValidator.validate_production_security!
            Flags.validate!
          end

          # @return [void]
          def configure_request_service!
            nil
          end

          # @return [void]
          def configure_runtime_logging!
            return unless defined?(Rack::Timeout::Logger)

            Rack::Timeout::Logger.logger = AppLogger.logger
          end
        end
      end
    end
  end
end
