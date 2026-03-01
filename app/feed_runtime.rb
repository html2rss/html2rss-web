# frozen_string_literal: true

require 'digest'
require 'time'

require_relative 'security_logger'

module Html2rss
  module Web
    ##
    # Cache-first feed runtime with optional async stale refresh.
    module FeedRuntime
      ##
      # Cached feed entry model.
      Entry = Data.define(:content, :cached_at, :expires_at)

      class << self
        # @param key [String]
        # @param ttl_seconds [Integer]
        # @param async_refresh [Boolean]
        # @param generator [Proc]
        # @yieldreturn [String]
        # @return [String]
        def read(key:, ttl_seconds:, async_refresh: false, &generator)
          return yield.to_s unless async_refresh

          entry = fetch_entry(key)
          return generate_and_store(key, ttl_seconds, &generator) unless entry

          return entry.content if fresh?(entry)

          enqueue_refresh(key, ttl_seconds, &generator) if within_stale_window?(entry, ttl_seconds)
          entry.content
        end

        # @param reason [String]
        # @return [nil]
        def clear!(reason: 'manual')
          mutex.synchronize do
            @cache = {}
            @pending_keys = Set.new
          end
          SecurityLogger.log_cache_lifecycle('feed_runtime', 'clear', reason: reason)
          nil
        end

        private

        # @param key [String]
        # @return [Entry, nil]
        def fetch_entry(key)
          mutex.synchronize { cache[key] }
        end

        # @param key [String]
        # @param ttl_seconds [Integer]
        # @yieldreturn [String]
        # @return [String]
        def generate_and_store(key, ttl_seconds)
          content = yield.to_s
          now = Time.now.utc
          entry = Entry.new(content: content, cached_at: now, expires_at: now + normalize_ttl(ttl_seconds))

          mutex.synchronize { cache[key] = entry }
          SecurityLogger.log_cache_lifecycle('feed_runtime', 'sync_write', key_hash: key_hash(key))
          content
        end

        # @param key [String]
        # @param ttl_seconds [Integer]
        # @yieldreturn [String]
        # @return [void]
        def enqueue_refresh(key, ttl_seconds, &generator)
          mutex.synchronize do
            return if pending_keys.include?(key)

            pending_keys.add(key)
            queue << [key, ttl_seconds, generator]
          end
          start_worker!
          SecurityLogger.log_cache_lifecycle('feed_runtime', 'enqueue_refresh', key_hash: key_hash(key))
        end

        # @return [void]
        def start_worker!
          return if @worker&.alive? # rubocop:disable ThreadSafety/ClassInstanceVariable

          # rubocop:disable ThreadSafety/NewThread
          @worker = Thread.new do # rubocop:disable ThreadSafety/ClassInstanceVariable
            Thread.current.abort_on_exception = false
            process_queue
          end
          # rubocop:enable ThreadSafety/NewThread
        end

        # @return [void]
        def process_queue
          loop do
            key, ttl_seconds, generator = queue.pop
            generate_and_store(key, ttl_seconds, &generator)
            SecurityLogger.log_cache_lifecycle('feed_runtime', 'async_refresh', key_hash: key_hash(key))
          rescue StandardError => error
            SecurityLogger.log_suspicious_activity('feed_runtime', 'refresh_failure',
                                                   key_hash: key_hash(key), error: error.message)
          ensure
            mutex.synchronize { pending_keys.delete(key) if key }
          end
        end

        # @param entry [Entry]
        # @return [Boolean]
        def fresh?(entry)
          Time.now.utc < entry.expires_at
        end

        # @param entry [Entry]
        # @param ttl_seconds [Integer]
        # @return [Boolean]
        def within_stale_window?(entry, ttl_seconds)
          stale_seconds = normalize_ttl(ttl_seconds) * stale_factor
          Time.now.utc <= (entry.expires_at + stale_seconds)
        end

        # @return [Queue]
        def queue
          @queue ||= Queue.new # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # @return [Hash{String=>Entry}]
        def cache
          @cache ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # @return [Set<String>]
        def pending_keys
          @pending_keys ||= Set.new # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # @return [Mutex]
        def mutex
          @mutex ||= Mutex.new # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # @param key [String]
        # @return [String]
        def key_hash(key)
          Digest::SHA256.hexdigest(key)[0..11]
        end

        # @param ttl_seconds [Integer]
        # @return [Integer]
        def normalize_ttl(ttl_seconds)
          value = ttl_seconds.to_i
          value.positive? ? value : 300
        end

        # @return [Integer]
        def stale_factor
          factor = ENV.fetch('ASYNC_FEED_REFRESH_STALE_FACTOR', '3').to_i
          factor.positive? ? factor : 3
        end
      end
    end
  end
end
