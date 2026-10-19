# frozen_string_literal: true

require 'rack/request'
require 'rack/response'
require 'rack/utils'

module Html2rss
  module Web
    ##
    # Rack middleware providing IP-based rate limiting with fiber-native tracking,
    # automated pruning, and standardized 429 error formatting.
    class RateLimiter
      ##
      # Encapsulates timestamp tracking and rate limit logic for a single client IP.
      class RequestTrack
        # @return [Array<Integer>]
        attr_reader :timestamps
        private :timestamps

        def initialize
          @timestamps = []
        end

        # Records request time, prunes old timestamps, and checks if limit is exceeded.
        #
        # @param now [Integer]
        # @param window_seconds [Integer]
        # @param max_requests [Integer]
        # @return [Array<(Boolean, Integer)>] limit exceeded flag and retry_after seconds.
        def record_and_check_limit(now, window_seconds, max_requests)
          window_start = now - window_seconds
          @timestamps.reject! { |t| t < window_start }

          if @timestamps.size >= max_requests
            oldest = @timestamps.first
            retry_after = [1, oldest + window_seconds - now].max
            [true, retry_after]
          else
            @timestamps << now
            [false, 0]
          end
        end

        # Prunes expired timestamps and deletes the key from history if empty.
        #
        # @param window_start [Integer]
        # @param history [Hash]
        # @param key [String]
        # @return [void]
        def prune(window_start, history, key)
          @timestamps.reject! { |t| t < window_start }
          history.delete(key) if @timestamps.empty?
          nil
        end
      end

      # @param app [#call]
      def initialize(app)
        @app = app
        @history = {}
        @last_pruned = 0
      end

      # @param env [Hash]
      # @return [Array<(Integer, Hash, #each)>]
      # rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength
      def call(env)
        return @app.call(env) unless Flags.rate_limit_enabled?

        request = Rack::Request.new(env)
        path = Rack::Utils.clean_path_info(request.path_info.to_s)
        return @app.call(env) if bypass?(path)

        prune_history_if_needed

        client_key = request.ip
        now = Time.now.to_i

        track = (@history[client_key] ||= RequestTrack.new)
        limit_exceeded, retry_after = track.record_and_check_limit(
          now,
          Flags.rate_limit_window_seconds,
          Flags.rate_limit_max_requests
        )

        if limit_exceeded
          SecurityLogger.log_rate_limit_exceeded(client_key, path, Flags.rate_limit_max_requests)

          # Ensure feed endpoints get feed-formatted errors
          if path.start_with?('/api/v1/feeds/') || !path.start_with?('/api/v1/')
            env[RequestTarget::ENV_KEY] = RequestTarget::FEED
          end

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

      # Prunes inactive IP tracks when history grows too large.
      # Utilizes a time-based throttle to minimize CPU overhead.
      # Hard-caps the history size to prevent OOM.
      #
      # @return [void]
      def prune_history_if_needed
        now = Time.now.to_i
        size = @history.size

        if size > 20_000
          handle_overflow(now)
        elsif size > 1000 && (now - @last_pruned) > 10
          @last_pruned = now
          prune_all_expired(now)
        end
        nil
      end

      # Handles history map overflow by logging a security event and evicting entries.
      #
      # @param now [Integer]
      # @return [void]
      # rubocop:disable-next Metrics/MethodLength
      def handle_overflow(now)
        @last_pruned = now
        prune_all_expired(now)

        post_prune_size = @history.size
        return if post_prune_size <= 20_000

        SecurityLogger.log_suspicious_activity(
          'system',
          'rate_limiter_history_overflow',
          { size: post_prune_size, action: 'prune_to_limit' }
        )

        needed = post_prune_size - 10_000
        evicted = 0
        @history.keys.shuffle.each do |key|
          break if evicted >= needed

          evicted += 1 if @history.delete(key)
        end
      end

      # Iterates over history and prunes inactive tracks.
      #
      # @param now [Integer]
      # @return [void]
      def prune_all_expired(now)
        window_start = now - Flags.rate_limit_window_seconds

        @history.each_key do |key|
          track = @history[key]
          track&.prune(window_start, @history, key)
        end
      end
    end
  end
end
