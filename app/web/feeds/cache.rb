# frozen_string_literal: true

require 'async'
require 'async/notification'
require 'digest'
require 'time'

module Html2rss
  module Web
    module Feeds
      ##
      # Fiber-native cache for canonical feed results.
      module Cache
        # rubocop:disable ThreadSafety/ClassInstanceVariable
        def self.entries
          @entries ||= {}
        end
        private_class_method :entries

        def self.in_flight
          @in_flight ||= {}
        end
        private_class_method :in_flight
        # rubocop:enable ThreadSafety/ClassInstanceVariable

        Entry = Data.define(:result, :expires_at)
        DEFAULT_TTL_SECONDS = 3600

        ##
        # Coordinates in-flight fiber coalescing for identical cache keys.
        class InFlight
          def initialize
            @notification = Async::Notification.new
            @completed = false
            @result = nil
            @error = nil
          end

          # @return [Object]
          def wait
            return @result if @completed && !@error
            raise @error if @completed && @error

            @notification.wait
            raise @error if @error

            @result
          end

          # @param result [Object]
          # @return [void]
          def success!(result)
            @result = result
            @completed = true
            @notification.signal(result)
          end

          # @param error [Exception]
          # @return [void]
          def failure!(error)
            @error = error
            @completed = true
            @notification.signal(error)
          end
        end
        private_constant :InFlight

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
          def fetch(key, ttl_seconds:, cacheable: true, &)
            entry = read_entry(key)
            return entry.result if fresh?(entry)
            return in_flight[key].wait if in_flight.key?(key)

            execute_fetch(key, ttl_seconds, cacheable, &)
          end

          # @param reason [String]
          # @return [nil]
          def clear!(reason: 'manual')
            entries.clear
            in_flight.clear
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
            entries.delete_if { |_k, v| v && now >= v.expires_at }
          end

          def execute_fetch(key, ttl_seconds, cacheable) # rubocop:disable Metrics/MethodLength
            job = in_flight[key] = InFlight.new
            begin
              result = yield
              write_entry(key, ttl_seconds, result) if cacheable_result?(cacheable, result)
              job.success!(result)
              result
            rescue Exception => error # rubocop:disable Lint/RescueException -- Async::Stop inherits from Exception
              job.failure!(error)
              raise
            ensure
              in_flight.delete(key)
            end
          end

          def prune_excess(max)
            excess = entries.size - (max * 0.9).to_i
            return if excess <= 0

            entries_by_expiration.first(excess).each { |pair| entries.delete(pair.first) }
          end

          def entries_by_expiration
            entries.select { |_k, v| v&.expires_at }
                   .sort_by { |_k, v| v.expires_at }
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
