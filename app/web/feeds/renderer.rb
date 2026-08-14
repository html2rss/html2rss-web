# frozen_string_literal: true

require 'json'
require 'time'

module Html2rss
  module Web
    module Feeds
      ##
      # Builds feed HTTP envelopes: status, headers, and serialized bodies.
      module Renderer
        class << self
          # Renders a RenderResult and configures the HTTP response headers and status.
          #
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param response [Rack::Response]
          # @param request [Rack::Request]
          # @return [String] serialized feed representation
          def render(result, response:, request:)
            format = FormatNegotiation.format_for_request(request)
            apply_response_envelope(response, result, format, request)
            call(result, format: format, request: request)
          end

          # Renders an error body and configures the HTTP response headers and status.
          # Empty and error responses are always plain text.
          #
          # @param message [String] the error message to display.
          # @param response [Rack::Response] the Rack response.
          # @return [String] plain-text error body
          def render_error(message, response:)
            response['Content-Type'] = FormatNegotiation::TEXT_PLAIN_CONTENT_TYPE
            HttpCache.expires_now(response)

            call_error(message: message)
          end

          private

          # @param response [Rack::Response]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param format [Symbol]
          # @param request [Rack::Request]
          # @return [void]
          def apply_response_envelope(response, result, format, request)
            response.status = status_for(result.status)
            response['Content-Type'] = response_content_type(result, format)
            apply_cache_headers(response, result)
            apply_vary_and_links(response, result, request)
          end

          # @param response [Rack::Response]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param request [Rack::Request]
          # @return [void]
          def apply_vary_and_links(response, result, request)
            if result.status == :ok
              apply_alternate_links(response, request)
              HttpCache.vary(response, 'Accept', 'Host')
            else
              HttpCache.vary(response, 'Accept')
            end
          end

          # Renders a RenderResult into the requested format.
          #
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param format [Symbol] :rss or :json_feed
          # @param request [Rack::Request, nil]
          # @return [String] serialized feed or plain-text empty/error body
          def call(result, format:, request: nil)
            case result.status
            when :ok
              render_success(result, format, request: request)
            when :empty
              render_empty(result)
            else
              call_error(message: result.message || HttpError::DEFAULT_MESSAGE)
            end
          end

          # Renders a plain-text error body.
          #
          # @param message [String] the error message to display.
          # @return [String] plain-text error body
          def call_error(message:)
            plain_text_body("Failed to generate feed: #{message}")
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param format [Symbol]
          # @return [String]
          def response_content_type(result, format)
            return FormatNegotiation::TEXT_PLAIN_CONTENT_TYPE if plain_response?(result)

            FormatNegotiation.content_type(format)
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [Boolean]
          def plain_response?(result)
            %i[empty error].include?(result.status)
          end

          # @param response [Rack::Response]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def apply_cache_headers(response, result)
            return HttpCache.expires_now(response) if result.status == :error

            HttpCache.expires(response, result.ttl_seconds, cache_control: 'public')
          end

          # @param response [Rack::Response]
          # @param request [Rack::Request]
          # @return [void]
          def apply_alternate_links(response, request)
            # Path-absolute relative targets (RFC 8288) so reverse-proxy Host/DNS cannot leak.
            base_path = FormatNegotiation.strip_known_extension(FormatNegotiation.request_path(request))
            rss_url = "#{base_path}.xml"
            json_url = "#{base_path}.json"

            response['Link'] = [
              "<#{rss_url}>; rel=\"alternate\"; type=\"application/rss+xml\"",
              "<#{json_url}>; rel=\"alternate\"; type=\"application/feed+json\""
            ].join(', ')
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param format [Symbol]
          # @param request [Rack::Request, nil]
          # @return [String]
          def render_success(result, format, request: nil)
            feed_result = result.payload.feed
            feed_url = canonical_feed_url(request)

            if format == FormatNegotiation::JSON_FEED
              JSON.generate(feed_result.to_json_feed(feed_url: feed_url))
            else
              feed_result.to_rss.to_s
            end
          end

          # @param request [Rack::Request, nil]
          # @return [String, nil]
          def canonical_feed_url(request)
            return unless request

            "#{request.base_url}#{FormatNegotiation.request_path(request)}"
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [String]
          def render_empty(result)
            plain_text_body(EmptyFeedCopy.plain_text(result.payload.url, result.payload.site_title))
          end

          # @param message [String]
          # @return [String]
          def plain_text_body(message)
            message.to_s.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '').strip
          end

          # @param status [Symbol]
          # @return [Integer]
          def status_for(status)
            return 200 if status == :ok
            return 422 if status == :empty

            500
          end
        end
      end
    end
  end
end
