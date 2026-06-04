# frozen_string_literal: true

require 'puppeteer'

module Html2rss
  class RequestService
    ##
    # Browserless.io strategy to request websites.
    #
    # Provide the WebSocket URL and your API token via environment variables:
    # - BROWSERLESS_IO_WEBSOCKET_URL
    # - BROWSERLESS_IO_API_TOKEN
    #
    # To use this strategy, you need to have a Browserless.io account or run a
    # local Browserless.io instance.
    #
    # @see https://www.browserless.io/
    #
    # To run a local Browserless.io instance, you can use the following Docker command:
    #
    # ```sh
    # docker run \
    #   --rm \
    #   -p 3000:3000 \
    #   -e "CONCURRENT=10" \
    #   -e "TOKEN=6R0W53R135510" \
    #   ghcr.io/browserless/chromium
    # ```
    #
    # When running locally, you can skip setting the environment variables, as above commands
    # are aligned with the default values.
    # @see https://github.com/browserless/browserless/pkgs/container/chromium
    class BrowserlessStrategy < Strategy
      ##
      # Executes a Browserless-backed request with the shared request policy.
      #
      # @return [Response] normalized request response
      # @raise [RequestTimedOut] if the browser session exceeds the configured timeout
      def execute
        validate_request!
        execute_browserless_request
      rescue Puppeteer::TimeoutError => error
        raise RequestTimedOut, error.message
      end

      ##
      # @return [String] the Browserless websocket endpoint with token query param
      # @raise [ArgumentError] if a custom endpoint is configured without an API token
      def browser_ws_endpoint
        @browser_ws_endpoint ||= begin
          ws_url = ENV.fetch('BROWSERLESS_IO_WEBSOCKET_URL', 'ws://127.0.0.1:3000')
          api_token = browserless_api_token(ws_url)

          "#{ws_url}?token=#{api_token}"
        end
      end

      private

      def validate_request!
        ctx.budget.consume!
        ctx.policy.validate_request!(url: ctx.url, origin_url: ctx.origin_url, relation: ctx.relation)
      end

      def execute_browserless_request
        connect_with_timeout_support do |browser|
          PuppetCommander.new(ctx, browser).call
        ensure
          browser.disconnect
        end
      end

      def protocol_timeout_ms
        ctx.policy.total_timeout_seconds * 1000
      end

      def connect_with_timeout_support(&)
        connect_browserless(protocol_timeout: protocol_timeout_ms, &)
      rescue ArgumentError => error
        raise unless unsupported_protocol_timeout?(error)

        connect_browserless(&)
      end

      def unsupported_protocol_timeout?(error)
        error.message.include?('unknown keyword: :protocol_timeout')
      end

      def connect_browserless(protocol_timeout: nil, &)
        connected = false

        Puppeteer.connect(**browserless_connect_options(protocol_timeout)) do |browser|
          connected = true
          yield browser
        end
      rescue ArgumentError => error
        handle_connection_error(error, connected:, protocol_timeout:)
      rescue StandardError => error
        handle_connection_error(error, connected:)
      end

      def browserless_connect_options(protocol_timeout)
        { browser_ws_endpoint:, protocol_timeout: }.compact
      end

      def handle_connection_error(error, connected:, protocol_timeout: nil)
        raise if connected || compatibility_timeout_error?(error, protocol_timeout:)

        raise BrowserlessConnectionFailed, browserless_connection_message(error), cause: error
      end

      def compatibility_timeout_error?(error, protocol_timeout:)
        protocol_timeout && unsupported_protocol_timeout?(error)
      end

      def browserless_connection_message(error)
        base = "Browserless connection failed (#{error.class}: #{error.message})."
        endpoint_hint = "Check BROWSERLESS_IO_WEBSOCKET_URL (currently #{browserless_websocket_url})."
        token_hint = 'Check BROWSERLESS_IO_API_TOKEN and ensure it matches your Browserless TOKEN.'
        local_hint = 'For local Browserless, confirm the service is running and reachable.'

        if likely_authentication_error?(error)
          "#{base} #{token_hint} #{endpoint_hint}"
        else
          "#{base} #{endpoint_hint} #{token_hint} #{local_hint}"
        end
      end

      def likely_authentication_error?(error)
        message = error.message.downcase
        message.include?('unauthorized') || message.include?('forbidden') || message.include?('401')
      end

      def browserless_websocket_url
        ENV.fetch('BROWSERLESS_IO_WEBSOCKET_URL', 'ws://127.0.0.1:3000')
      end

      def browserless_api_token(ws_url)
        ENV.fetch('BROWSERLESS_IO_API_TOKEN') do
          return '6R0W53R135510' if ws_url == 'ws://127.0.0.1:3000'

          raise BrowserlessConfigurationError,
                'BROWSERLESS_IO_API_TOKEN is required for custom Browserless endpoints. ' \
                'Set BROWSERLESS_IO_API_TOKEN or use ws://127.0.0.1:3000 for local defaults.'
        end
      end
    end
  end
end
