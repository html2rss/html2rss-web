# frozen_string_literal: true

module Html2rss
  module Web
    module Telemetry
      ##
      # Starts optional OTLP tracing in the worker process.
      module Boot
        SDK_REQUIRES = %w[
          opentelemetry/sdk
          opentelemetry/exporter/otlp
          opentelemetry/instrumentation/rack
          opentelemetry/instrumentation/faraday
          opentelemetry/instrumentation/net/http
        ].freeze

        class << self
          # Configures the trace SDK when an OTLP endpoint is set.
          # Idempotent for the current process id. A new process id configures again.
          #
          # @return [void]
          def start!
            Metrics.start!
            return if tracing?

            return unless endpoint_configured?

            load_sdk!
            apply_export_defaults!
            configure_sdk!
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @started_pid = Process.pid
            register_flush!
          end

          # @return [Boolean]
          def tracing?
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @started_pid == Process.pid
          end

          # Deploy revision shared by traces and +html2rss_build_info+.
          #
          # @return [String]
          def revision
            "#{RuntimeEnv.build_tag}+#{RuntimeEnv.git_sha}"
          end

          private

          # @return [void]
          def reset!
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @started_pid = nil
          end

          # @return [Boolean]
          def endpoint_configured?
            !ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', '').to_s.strip.empty?
          end

          # @return [void]
          def load_sdk!
            SDK_REQUIRES.each { |path| require path }
            nil
          end

          # @return [void]
          def apply_export_defaults!
            ENV['OTEL_PROPAGATORS'] = 'tracecontext'
            apply_sampler_default!
            apply_protocol_default!
            nil
          end

          # @return [void]
          def apply_sampler_default!
            return unless ENV.fetch('OTEL_TRACES_SAMPLER', '').strip.empty?

            ENV['OTEL_TRACES_SAMPLER'] = 'parentbased_traceidratio'
            return unless ENV.fetch('OTEL_TRACES_SAMPLER_ARG', '').strip.empty?

            ENV['OTEL_TRACES_SAMPLER_ARG'] = '0.1'
          end

          # @return [void]
          def apply_protocol_default!
            return unless ENV.fetch('OTEL_EXPORTER_OTLP_PROTOCOL', '').strip.empty?

            ENV['OTEL_EXPORTER_OTLP_PROTOCOL'] = 'http/protobuf'
          end

          # @return [void]
          def configure_sdk!
            OpenTelemetry::SDK.configure do |config|
              config.service_name = service_name
              config.service_version = revision
              Tracing.install(config)
            end
            nil
          end

          # @return [String]
          def service_name
            name = ENV.fetch('OTEL_SERVICE_NAME', '').strip
            name.empty? ? 'html2rss-web' : name
          end

          # @return [void]
          def register_flush!
            register_exit_hook { flush_spans! }
            nil
          end

          # @return [void]
          def register_exit_hook(&)
            at_exit(&)
            nil
          end

          # @return [void]
          def flush_spans!
            return unless defined?(OpenTelemetry)

            provider = OpenTelemetry.tracer_provider
            provider.force_flush if provider.respond_to?(:force_flush)
            nil
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
