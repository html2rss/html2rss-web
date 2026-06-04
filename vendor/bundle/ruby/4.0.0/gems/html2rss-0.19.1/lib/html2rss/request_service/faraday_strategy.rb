# frozen_string_literal: true

require 'faraday'
require 'faraday/follow_redirects'
require 'faraday/gzip'

module Html2rss
  class RequestService
    ##
    # Strategy to use Faraday for the request.
    # @see https://rubygems.org/gems/faraday
    class FaradayStrategy < Strategy
      ##
      # Restores buffered streamed bytes so response middleware can process them.
      class StreamingBodyMiddleware < Faraday::Middleware
        # Request-context key used to store streamed chunks before middleware completion.
        STREAM_BUFFER_KEY = :html2rss_stream_buffer

        # @param env [Faraday::Env] completed response environment
        # @return [void]
        def on_complete(env)
          buffer = env.request.context&.delete(STREAM_BUFFER_KEY)
          return if buffer.nil? || buffer.empty?

          env.body = buffer
        end
      end

      ##
      # Executes a request with runtime policy enforcement.
      #
      # @return [Response] normalized request response
      # @note Unlike BrowserlessStrategy, Faraday does not expose the remote IP after connect.
      #   SSRF protection here is pre-connection only (DNS resolution via Policy).
      #   A DNS rebinding attack between resolution and connect cannot be caught at this layer.
      def execute
        deadline = request_deadline
        response_guard, response = perform_request(deadline:)
        response_guard.inspect_body!(response.body)
        build_response(response)
      rescue Faraday::TimeoutError, Timeout::Error => error
        raise RequestTimedOut, error.message
      end

      private

      def request_deadline
        monotonic_now + ctx.policy.total_timeout_seconds
      end

      def perform_request(deadline:)
        response_guard = ResponseGuard.new(policy: ctx.policy)
        response = faraday_request(response_guard, deadline:, streaming_buffer: true)
        response = retry_without_streaming(response_guard, deadline:) if retry_without_streaming?(response)
        [response_guard, response]
      end

      def build_response(response)
        Response.new(body: response.body, headers: response.headers, url: response_url(response),
                     status: response.status)
      end

      def validate_request!(consume_budget: true)
        ctx.budget.consume! if consume_budget
        ctx.policy.validate_request!(url: ctx.url, origin_url: ctx.origin_url, relation: ctx.relation)
      end

      def faraday_request(response_guard, deadline:, streaming_buffer:, consume_budget: true)
        validate_request!(consume_budget:)

        client.get do |req|
          apply_timeouts(req, deadline:)
          buffer = prepare_stream_buffer(req) if streaming_buffer
          req.options.on_data = on_data_callback(response_guard, buffer)
        end
      end

      def retry_without_streaming(response_guard, deadline:)
        faraday_request(response_guard, deadline:, streaming_buffer: false, consume_budget: false)
      end

      def client
        @client ||= Faraday.new(url: ctx.url.to_s, headers: ctx.headers) do |faraday|
          faraday.use Faraday::FollowRedirects::Middleware, limit: ctx.policy.max_redirects, callback: redirect_callback
          faraday.request :gzip
          faraday.use StreamingBodyMiddleware
          faraday.adapter Faraday.default_adapter
        end
      end

      def apply_timeouts(request, deadline:)
        remaining_timeout = remaining_timeout_seconds(deadline)
        request.options.timeout = remaining_timeout
        request.options.open_timeout = [ctx.policy.connect_timeout_seconds, remaining_timeout].min
        request.options.read_timeout = [ctx.policy.read_timeout_seconds, remaining_timeout].min
      end

      def prepare_stream_buffer(request)
        request.options.context ||= {}
        request.options.context[StreamingBodyMiddleware::STREAM_BUFFER_KEY] = +''
      end

      def on_data_callback(response_guard, buffer)
        proc do |chunk, total_bytes, env|
          response_guard.inspect_chunk!(total_bytes:, headers: env&.response_headers)
          buffer&.<< chunk
        end
      end

      def remaining_timeout_seconds(deadline)
        remaining = deadline - monotonic_now
        raise RequestTimedOut, 'Request timed out' if remaining <= 0

        remaining
      end

      def retry_without_streaming?(response)
        return false if response.body.to_s.empty? == false
        return false unless response_success?(response)

        final_url = response.env&.url
        return false unless final_url

        final_url.to_s != ctx.url.to_s
      end

      def response_success?(response)
        return true if response.status.nil?

        response.status >= 200 && response.status < 300
      end

      def response_url(response)
        return ctx.url unless (url = response.env&.url)

        Html2rss::Url.from_absolute(url.to_s)
      end

      def redirect_callback
        lambda do |old_env, new_env|
          from_url = normalize_url(old_env[:url])
          to_url = normalize_url(new_env[:url])
          ctx.policy.validate_redirect!(from_url:, to_url:, origin_url: ctx.origin_url, relation: ctx.relation)
        end
      end

      def normalize_url(url)
        Html2rss::Url.from_absolute(url.to_s)
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
