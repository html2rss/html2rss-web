# frozen_string_literal: true

require 'digest'
require 'time'

require_relative '../cache_ttl'
require_relative '../security_logger'

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
          # @yieldreturn [Html2rss::Web::Feeds::Result]
          # @return [Html2rss::Web::Feeds::Result]
          def fetch(key, ttl_seconds:)
            entry = read_entry(key)
            return entry.result if fresh?(entry)

            result = yield
            write_entry(key, ttl_seconds, result)
            result
          end

          # @param reason [String]
          # @return [nil]
          def clear!(reason: 'manual')
            @entries = {} # rubocop:disable ThreadSafety/ClassInstanceVariable
            SecurityLogger.log_cache_lifecycle('feeds_cache', 'clear', reason: reason)
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
          # @param result [Html2rss::Web::Feeds::Result]
          # @return [void]
          def write_entry(key, ttl_seconds, result)
            entries[key] = Entry.new(result: result, expires_at: Time.now.utc + normalize_ttl(ttl_seconds))
            SecurityLogger.log_cache_lifecycle('feeds_cache', 'write', key_hash: key_hash(key))
          end

          # @return [Hash{String=>Entry}]
          def entries
            @entries ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
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
