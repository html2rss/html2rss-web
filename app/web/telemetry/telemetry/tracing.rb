# frozen_string_literal: true

require 'uri'

module Html2rss
  module Web
    module Telemetry
      ##
      # Installs trace instrumentation and keeps exported span attributes safe.
      module Tracing
        METHOD_KEYS = %w[http.request.method http.method].freeze
        STATUS_KEYS = %w[http.response.status_code http.status_code].freeze
        PEER_KEYS = %w[server.address net.peer.name peer.service].freeze
        PRODUCT_KEYS = %w[
          html2rss.route_group html2rss.operation html2rss.result html2rss.reason
        ].freeze
        CLASS_NAME = /\A[A-Z][\w:]*\z/

        ##
        # Rewrites span attributes at finish, before the SDK freezes them.
        class AttributeProcessor
          # @param _span [Object]
          # @param _parent_context [Object]
          # @return [void]
          def on_start(_span, _parent_context) = nil

          # Drops unsafe attributes and copies the request route group onto a server span.
          #
          # @param span [Object]
          # @return [void]
          def on_finishing(span)
            filtered = filtered_attributes(read_attributes(span))
            copy_route_group!(filtered, span)
            write_attributes(span, filtered)
            nil
          end

          # @param _span [Object]
          # @return [void]
          def on_finish(_span) = nil

          # @return [void]
          def force_flush(**) = nil

          # @return [void]
          def shutdown(**) = nil

          private

          # @param attributes [Hash]
          # @return [Hash{String=>Object}]
          def filtered_attributes(attributes)
            normalized = normalize(attributes)
            {}.tap do |kept|
              copy_alias(kept, normalized, METHOD_KEYS)
              copy_alias(kept, normalized, STATUS_KEYS)
              copy_peers(kept, normalized)
              copy_error_type(kept, normalized)
              copy_product(kept, normalized)
            end
          end

          # @param attributes [Hash]
          # @return [Hash{String=>Object}]
          def normalize(attributes)
            attributes.each_with_object({}) do |(key, value), memo|
              memo[key.to_s] = value
            end
          end

          # @param kept [Hash{String=>Object}]
          # @param attributes [Hash{String=>Object}]
          # @param keys [Array<String>]
          # @return [void]
          def copy_alias(kept, attributes, keys)
            value = keys.lazy.filter_map { |key| attributes[key] }.first
            return if value.nil?

            keys.each { |key| kept[key] = value }
          end

          # @param kept [Hash{String=>Object}]
          # @param attributes [Hash{String=>Object}]
          # @return [void]
          def copy_peers(kept, attributes)
            PEER_KEYS.each do |key|
              host = host_from(attributes[key])
              kept[key] = host unless host.nil?
            end
          end

          # @param value [Object]
          # @return [String, nil]
          def host_from(value)
            return if value.nil?

            text = value.to_s.strip
            return if text.empty?
            return url_host(text) if text.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
            return if text.include?('/') || text.include?('?')

            text
          end

          # @param text [String]
          # @return [String, nil]
          def url_host(text)
            URI.parse(text).host
          rescue URI::InvalidURIError
            nil
          end

          # @param kept [Hash{String=>Object}]
          # @param attributes [Hash{String=>Object}]
          # @return [void]
          def copy_error_type(kept, attributes)
            name = class_name(attributes['error.type'])
            kept['error.type'] = name unless name.nil?
          end

          # @param value [Object]
          # @return [String, nil]
          def class_name(value)
            return value.name if value.is_a?(Module)
            return value.class.name if value.is_a?(Exception)

            text = value.to_s
            text if CLASS_NAME.match?(text)
          end

          # @param kept [Hash{String=>Object}]
          # @param attributes [Hash{String=>Object}]
          # @return [void]
          def copy_product(kept, attributes)
            PRODUCT_KEYS.each do |key|
              value = attributes[key]
              kept[key] = value unless value.nil?
            end
          end

          # @param kept [Hash{String=>Object}]
          # @param span [Object]
          # @return [void]
          def copy_route_group!(kept, span)
            return unless server_span?(span)
            return unless kept['html2rss.route_group'].nil?

            group = RequestContext.current&.route_group.to_s
            kept['html2rss.route_group'] = group unless group.empty?
          end

          # @param span [Object]
          # @return [Boolean]
          def server_span?(span)
            span.respond_to?(:kind) && span.kind.to_s == 'server'
          end

          # @param span [Object]
          # @return [Hash]
          def read_attributes(span)
            stored = span.instance_variable_get(:@attributes) if span.instance_variable_defined?(:@attributes)
            return stored if stored.is_a?(Hash)
            return span.attributes if span.respond_to?(:attributes) && span.attributes.is_a?(Hash)

            {}
          end

          # @param span [Object]
          # @param attributes [Hash{String=>Object}]
          # @return [void]
          def write_attributes(span, attributes)
            if span.instance_variable_defined?(:@attributes)
              span.instance_variable_set(:@attributes, attributes)
              return
            end

            current = span.attributes
            current.clear
            attributes.each { |key, value| current[key] = value }
          end
        end

        class << self
          # Marks the current recording span with a journey before it finishes.
          #
          # @param group [String]
          # @return [void]
          def route_group!(group)
            current_span&.set_attribute('html2rss.route_group', group.to_s)
            nil
          rescue StandardError
            nil
          end

          # Copies an outcome onto the current recording span.
          #
          # @param outcome [Html2rss::Web::Telemetry::Outcome]
          # @return [void]
          def annotate!(outcome)
            span = current_span
            return if span.nil?

            span.set_attribute('html2rss.operation', outcome.operation)
            span.set_attribute('html2rss.result', outcome.result)
            span.set_attribute('html2rss.reason', outcome.reason)
            nil
          rescue StandardError
            nil
          end

          # @param config [Object]
          # @return [void]
          def install(config)
            config.add_span_processor(AttributeProcessor.new)
            config.add_span_processor(exporter_processor)
            install_instrumentation(config)
            nil
          end

          # Wraps +app+ with the Rack instrumentation when tracing is active.
          # The wrapper sits inside {RequestContextMiddleware} so the server span
          # finishes while the request context is still set.
          #
          # @param app [#call]
          # @return [#call]
          def wrap(app)
            return app unless Boot.tracing?

            middleware, argument = rack_middleware
            return middleware.new(app) if argument.nil?

            middleware.new(app, argument)
          end

          private

          # @return [Object, nil]
          def current_span
            return unless defined?(::OpenTelemetry::Trace)

            span = ::OpenTelemetry::Trace.current_span
            return unless span.respond_to?(:recording?) && span.recording?

            span
          end

          # Rack, Faraday, and Net::HTTP in this bundle do not capture bodies.
          # Empty Rack header lists keep headers off the span. Those libraries
          # still record query strings; {AttributeProcessor} drops them.
          #
          # @param config [Object]
          # @return [void]
          def install_instrumentation(config)
            config.use('OpenTelemetry::Instrumentation::Rack', rack_config)
            config.use('OpenTelemetry::Instrumentation::Faraday', faraday_config)
            config.use('OpenTelemetry::Instrumentation::Net::HTTP', net_http_config)
            nil
          end

          # @return [Hash]
          def rack_config
            {
              allowed_request_headers: [],
              allowed_response_headers: []
            }
          end

          # @return [Hash]
          def faraday_config
            { enable_internal_instrumentation: false }
          end

          # @return [Hash]
          def net_http_config
            {}
          end

          # @return [Object]
          def exporter_processor
            ::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
              ::OpenTelemetry::Exporter::OTLP::Exporter.new
            )
          end

          # @return [Array]
          def rack_middleware
            ::OpenTelemetry::Instrumentation::Rack::Instrumentation.instance.middleware_args
          end
        end
      end
    end
  end
end
