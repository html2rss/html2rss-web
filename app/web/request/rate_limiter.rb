# frozen_string_literal: true

require 'concurrent/map'
require 'rack/request'
require 'rack/response'

module Html2rss
  module Web
    ##
    # Rack middleware providing IP-based rate limiting with thread-safe tracking,
    # automated pruning, and standardized 429 error formatting.
    class RateLimiter
      ##
      # Encapsulates timestamp tracking and rate limit logic for a single client IP.
      class RequestTrack
        def initialize
          @mutex = Mutex.new
          @timestamps = []
        end

        # Records request time, prunes old timestamps, and checks if limit is exceeded.
        #
        # @param now [Integer]
        # @param window_seconds [Integer]
        # @param max_requests [Integer]
        # @return [Array<(Boolean, Integer, nil)>] limit exceeded flag and retry_after seconds.
        # rubocop:disable Metrics/MethodLength
        def record_and_check_limit(now, window_seconds, max_requests)
          @mutex.synchronize do
            window_start = now - window_seconds
            @timestamps.reject! { |t| t < window_start }

            if @timestamps.size >= max_requests
              oldest = @timestamps.min
              retry_after = [1, oldest + window_seconds - now].max
              [true, retry_after]
            else
              @timestamps << now
              [false, nil]
            end
          end
        end
        # rubocop:enable Metrics/MethodLength

        # Prunes expired timestamps and checks if the track is empty.
        #
        # @param window_start [Integer]
        # @return [Boolean] true if no timestamps remain.
        def prune(window_start)
          @mutex.synchronize do
            @timestamps.reject! { |t| t < window_start }
            @timestamps.empty?
          end
        end
      end

      # @param app [#call]
      def initialize(app)
        @app = app
        @history = Concurrent::Map.new
      end

      # @param env [Hash]
      # @return [Array<(Integer, Hash, #each)>]
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def call(env)
        return @app.call(env) unless Flags.rate_limit_enabled?

        request = Rack::Request.new(env)
        path = request.path_info.to_s
        return @app.call(env) if bypass?(path)

        prune_history_if_needed

        client_key = request.ip
        now = Time.now.to_i
        track = @history.compute_if_absent(client_key) { RequestTrack.new }

        limit_exceeded, retry_after = track.record_and_check_limit(
          now,
          Flags.rate_limit_window_seconds,
          Flags.rate_limit_max_requests
        )

        if limit_exceeded
          error = TooManyRequestsError.new
          response = Rack::Response.new
          response.status = 429
          response['Retry-After'] = retry_after.to_s

          body = ErrorResponder.respond(request: request, response: response, error: error)
          response.write(body)
          return response.finish
        end

        @app.call(env)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      # Bypasses rate limiting for root, static assets, and health checks.
      #
      # @param path [String]
      # @return [Boolean]
      def bypass?(path)
        path == '/' ||
          path.start_with?('/assets/') ||
          path == '/api/v1/health' ||
          path.start_with?('/api/v1/health/')
      end

      # Prunes inactive IP tracks on 1% of requests or when history grows too large.
      #
      # @return [void]
      # rubocop:disable Metrics/MethodLength
      def prune_history_if_needed
        return unless @history.size > 1000 || Random.rand(100).zero?

        now = Time.now.to_i
        window_start = now - Flags.rate_limit_window_seconds

        @history.each_key do |key|
          track = @history[key]
          if track
            is_empty = track.prune(window_start)
            @history.delete(key) if is_empty
          end
        end
        nil
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
