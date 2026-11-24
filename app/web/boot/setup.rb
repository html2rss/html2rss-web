# frozen_string_literal: true

module Html2rss
  module Web
    module Boot
      ##
      # Applies boot-time runtime configuration outside the Roda class body.
      module Setup
        # Documentation site root, shown in the container logs.
        DOCS_URL = 'https://html2rss.github.io'
        # Troubleshooting page, shown when boot fails.
        TROUBLESHOOTING_URL = "#{DOCS_URL}/troubleshooting/troubleshooting/".freeze

        class << self
          # Validates environment configuration and wires the request service, then logs the docs URL.
          # On failure (including a validator's `exit 1`) logs the troubleshooting URL and re-raises.
          #
          # @return [void]
          def call!
            begin
              boot!
            rescue StandardError, SystemExit => error
              name = error.class.name
              text = "html2rss-web failed to start (#{name}). Troubleshooting: #{TROUBLESHOOTING_URL}"
              log_docs!('app.boot_failed', TROUBLESHOOTING_URL, message: text, level: :error, error_class: name)
              raise
            end
            log_docs!('app.docs', DOCS_URL, message: "html2rss-web is ready. Documentation and setup help: #{DOCS_URL}")
          end

          private

          # @return [void]
          def boot!
            Boot.eager_load! unless EnvironmentValidator.development?
            validate_environment!
            RuntimeEnv.capture!
            Sentry.configure!
            configure_gem_defaults!
            log_startup!
          end

          # @return [void]
          def configure_gem_defaults!
            global_config = LocalConfig.global
            Html2rss.configure do |config|
              config.headers = global_config[:headers] if global_config[:headers]
              config.stylesheets = global_config[:stylesheets] if global_config[:stylesheets]
              config.logger_formatter = AppLogger.gem_formatter
            end
          end

          # @return [void]
          def validate_environment!
            EnvironmentValidator.validate_environment!
            EnvironmentValidator.validate_production_security!
            Flags.validate!
          end

          # @param event_name [String]
          # @param url [String]
          # @param level [Symbol]
          # @param message [String] plain-language line for people reading the container logs
          # @param extra [Hash]
          # @return [void]
          def log_docs!(event_name, url, message:, level: :info, **extra)
            AppLogger.logger.public_send(
              level, { component: 'boot', message:, event_name:, docs_url: url, **extra }.to_json
            )
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
