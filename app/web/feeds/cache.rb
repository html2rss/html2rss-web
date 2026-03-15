# frozen_string_literal: true

require 'digest'
require 'time'

module Html2rss
  module Web
    module Feeds
      ##
      # Small synchronous cache for canonical feed results.
      module Cache
        Entry = Data.define(:result, :expires_at)

        class << self
          # @param key [String]
          # @param ttl_seconds [Integer]
          # @param cacheable [Boolean, Proc]
          # @yieldreturn [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def fetch(key, ttl_seconds:, cacheable: true)
            lock.synchronize do
              entry = read_entry(key)
              return entry.result if fresh?(entry)

              result = yield
              return result unless cacheable_result?(cacheable, result)

              write_entry(key, ttl_seconds, result)
              result
            end
          end

          # @param reason [String]
          # @return [nil]
          def clear!(reason: 'manual')
            lock.synchronize do
              @entries = {}
              SecurityLogger.log_cache_lifecycle('feeds_cache', 'clear', reason: reason)
            end
            nil
          end

          private

          # @param key [String]
          # @return [Entry, nil]
          def read_entry(key)
            entries[key]
          end

          # @param entry [Entry, nil]
          # @return [Boolean]
          def fresh?(entry)
            entry && Time.now.utc < entry.expires_at
          end

          # @param key [String]
          # @param ttl_seconds [Integer]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def write_entry(key, ttl_seconds, result)
            entries[key] = Entry.new(result: result, expires_at: Time.now.utc + normalize_ttl(ttl_seconds))
            SecurityLogger.log_cache_lifecycle('feeds_cache', 'write', key_hash: key_hash(key))
          end

          # @param cacheable [Boolean, Proc]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [Boolean]
          def cacheable_result?(cacheable, result)
            return cacheable.call(result) if cacheable.respond_to?(:call)

            cacheable
          end

          # @return [Hash{String=>Entry}]
          def entries
            @entries ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
          end

          # @return [Mutex]
          def lock
            @lock ||= Mutex.new # rubocop:disable ThreadSafety/ClassInstanceVariable
          end

          # @param ttl_seconds [Integer]
          # @return [Integer]
          def normalize_ttl(ttl_seconds)
            ttl_seconds.to_i.positive? ? ttl_seconds.to_i : CacheTtl::DEFAULT_SECONDS
          end

          # @param key [String]
          # @return [String]
          def key_hash(key)
            Digest::SHA256.hexdigest(key)[0..11]
          end
        end
      end
    end
  end
end
