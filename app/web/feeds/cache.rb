# frozen_string_literal: true

require 'concurrent/map'
require 'digest'
require 'time'

module Html2rss
  module Web
    module Feeds
      ##
      # Small synchronous cache for canonical feed results.
      module Cache
        # rubocop:disable ThreadSafety/ClassInstanceVariable
        def self.entries
          @entries ||= Concurrent::Map.new
        end
        # rubocop:enable ThreadSafety/ClassInstanceVariable
        private_class_method :entries

        Entry = Data.define(:result, :expires_at)

        class << self
          # @param key [String]
          # @param ttl_seconds [Integer]
          # @param cacheable [Boolean, Proc]
          # @yieldreturn [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
          def fetch(key, ttl_seconds:, cacheable: true)
            entry = read_entry(key)
            return entry.result if fresh?(entry)

            result = yield

            return result unless cacheable_result?(cacheable, result)

            write_entry(key, ttl_seconds, result)
            result
          end

          # @param reason [String]
          # @return [nil]
          def clear!(reason: 'manual')
            entries.clear
            SecurityLogger.log_cache_lifecycle('feeds_cache', 'clear', reason: reason)
            nil
          end

          private

          def read_entry(key)
            entries[key]
          end

          # @param entry [Entry, nil]
          # @return [Boolean]
          def fresh?(entry)
            entry && Time.now.utc < entry.expires_at
          end

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
