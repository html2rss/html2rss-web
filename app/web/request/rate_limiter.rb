# frozen_string_literal: true

require 'concurrent/map'
require 'rack/request'
require 'rack/response'
require 'rack/utils'

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
          @deleted = false
        end

        # Records request time, prunes old timestamps, and checks if limit is exceeded.
        #
        # @param now [Integer]
        # @param window_seconds [Integer]
        # @param max_requests [Integer]
        # @return [Array<(Boolean, Integer, Boolean)>] limit exceeded flag, retry_after seconds, and deleted flag.
        # rubocop:disable Metrics/MethodLength
        def record_and_check_limit(now, window_seconds, max_requests)
          @mutex.synchronize do
            return [false, 0, true] if @deleted

            window_start = now - window_seconds
            @timestamps.reject! { |t| t < window_start }

            if @timestamps.size >= max_requests
              oldest = @timestamps.first
              retry_after = [1, oldest + window_seconds - now].max
              [true, retry_after, false]
            else
              @timestamps << now
              [false, 0, false]
            end
          end
        end
        # rubocop:enable Metrics/MethodLength

        # Prunes expired timestamps and deletes the key from history if empty.
        # Uses non-blocking try_lock to avoid blocking the pruning thread.
        #
        # @param window_start [Integer]
        # @param history [Concurrent::Map]
        # @param key [String]
        # @return [Boolean] true if key was pruned and deleted.
        # rubocop:disable Metrics/MethodLength
        def prune(window_start, history, key)
          return false unless @mutex.try_lock

          begin
            @timestamps.reject! { |t| t < window_start }
            if @timestamps.empty?
              if history.delete_pair(key, self)
                @deleted = true
                true
              else
                false
              end
            else
              false
            end
          ensure
            @mutex.unlock
          end
        end
        # rubocop:enable Metrics/MethodLength
      end

      # @param app [#call]
      def initialize(app)
        @app = app
        @history = Concurrent::Map.new
        @last_pruned = 0
        @prune_mutex = Mutex.new
      end

      # @param env [Hash]
      # @return [Array<(Integer, Hash, #each)>]
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def call(env)
        return @app.call(env) unless Flags.rate_limit_enabled?

        request = Rack::Request.new(env)
        path = Rack::Utils.clean_path_info(request.path_info.to_s)
        return @app.call(env) if bypass?(path)

        prune_history_if_needed

        client_key = request.ip
        now = Time.now.to_i

        limit_exceeded = false
        retry_after = nil

        loop do
          track = @history.compute_if_absent(client_key) { RequestTrack.new }

          exceeded, after, deleted = track.record_and_check_limit(
            now,
            Flags.rate_limit_window_seconds,
            Flags.rate_limit_max_requests
          )

          if deleted
            @history.delete_pair(client_key, track)
            next
          end

          limit_exceeded = exceeded
          retry_after = after
          break
        end

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

      # Prunes inactive IP tracks when history grows too large.
      # Utilizes a prune mutex and a time-based throttle to minimize CPU overhead.
      # Hard-caps the history size to prevent OOM.
      #
      # @return [void]
      # rubocop:disable Metrics/MethodLength
      def prune_history_if_needed
        now = Time.now.to_i
        size = @history.size

        if size > 20_000
          @prune_mutex.synchronize do
            handle_overflow(now) if @history.size > 20_000
          end
        elsif size > 1000 && (now - @last_pruned) > 10 && @prune_mutex.try_lock
          begin
            @last_pruned = now
            prune_all_expired(now)
          ensure
            @prune_mutex.unlock
          end
        end
        nil
      end
      # rubocop:enable Metrics/MethodLength

      # Handles history map overflow by logging a security event and evicting entries.
      #
      # @param now [Integer]
      # @return [void]
      # rubocop:disable Metrics/MethodLength
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
        @history.each_key do |key|
          break if evicted >= needed

          @history.delete(key)
          evicted += 1
        end
      end
      # rubocop:enable Metrics/MethodLength

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
