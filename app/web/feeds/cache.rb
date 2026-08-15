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
        DEFAULT_TTL_SECONDS = 3600

        class << self
          # Converts feed-provided minutes to seconds with a safe fallback.
          #
          # @param value [Object] TTL in minutes-like form.
          # @param default [Integer] seconds used when value is missing or non-positive.
          # @return [Integer] positive cache TTL in seconds.
          def seconds_from_minutes(value, default: DEFAULT_TTL_SECONDS)
            minutes = value.to_i
            return default unless minutes.positive?

            minutes * 60
          end

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
            Observability.emit(
              event_name: 'cache.lifecycle',
              outcome: 'success',
              details: { component: 'feeds_cache', event: 'clear', reason: }
            )
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
            prune_if_needed
            entries[key] = Entry.new(result: result, expires_at: Time.now.utc + normalize_ttl(ttl_seconds))
            Observability.emit(
              event_name: 'cache.lifecycle',
              outcome: 'success',
              details: { component: 'feeds_cache', event: 'write', key_hash: key_hash(key) }
            )
          end

          # Prunes expired entries first. If still over the max limit, prunes entries expiring soonest.
          #
          # @return [void]
          def prune_if_needed
            max = Flags.feeds_cache_max_size
            return if entries.size < max

            prune_expired
            prune_excess(max) if entries.size >= max
          end

          def prune_expired
            now = Time.now.utc
            entries.each_pair { |k, v| entries.delete(k) if v && now >= v.expires_at }
          end

          def prune_excess(max)
            excess = entries.size - (max * 0.9).to_i
            return if excess <= 0

            entries_by_expiration.first(excess).each { entries.delete(it.first) }
          end

          def entries_by_expiration
            candidates = []
            entries.each_pair { |k, v| candidates << [k, v.expires_at] if v&.expires_at }
            candidates.sort_by!(&:last)
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
            ttl_seconds.to_i.positive? ? ttl_seconds.to_i : DEFAULT_TTL_SECONDS
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
