# frozen_string_literal: true

require 'json'
require 'rack/attack'
require_relative '../app/security_logger'

module Html2rss
  module Web
    # Minimal in-memory store compatible with Rack::Attack expectations
    class RackAttackStore
      def initialize
        @data = {}
        @mutex = Mutex.new
      end

      def read(key)
        synchronize { value_for(key) }
      end

      def write(key, value, expires_in:)
        synchronize do
          @data[key] = build_entry(value, expires_in)
          true
        end
      end

      def delete(key)
        synchronize { @data.delete(key) }
      end

      def delete_matched(pattern)
        synchronize do
          @data.delete_if { |existing_key, _| File.fnmatch?(pattern, existing_key) }
          true
        end
      end

      def increment(key, amount = 1, expires_in:)
        synchronize do
          entry = entry_for(key)
          new_value = (entry&.fetch(:value, nil) || 0) + amount
          @data[key] = build_entry(new_value, expires_in)
          new_value
        end
      end

      private

      def synchronize(&)
        mutex.synchronize(&)
      end

      def entry_for(key)
        entry = @data[key]
        return unless entry

        if expired?(entry)
          @data.delete(key)
          nil
        else
          entry
        end
      end

      def value_for(key)
        entry_for(key)&.fetch(:value, nil)
      end

      def build_entry(value, expires_in)
        { value: value, expires_at: expires_at(expires_in) }
      end

      def expires_at(expires_in)
        return nil unless expires_in

        current_time + expires_in
      end

      def expired?(entry)
        expires_at = entry[:expires_at]
        expires_at && expires_at <= current_time
      end

      def current_time
        Process.clock_gettime(Process::CLOCK_REALTIME)
      end

      attr_reader :mutex
    end
  end
end

# In-memory store (resets on restart)
module Html2rss
  module Web
    # Provides consistent throttled responses for Rack::Attack
    module RackAttackResponse
      class << self
        def call(env)
          request = Rack::Request.new(env)
          match_data = env['rack.attack.match_data'] || {}
          limit = match_data[:limit] || RackAttack::DEFAULT_LIMIT

          SecurityLogger.log_rate_limit_exceeded(request.ip, request.path, limit)

          retry_after = RackAttack::DEFAULT_WINDOW
          return api_response(retry_after) if request.path.start_with?('/api/')

          text_response(retry_after)
        end

        private

        def api_response(retry_after)
          body = {
            success: false,
            error: { code: 'TOO_MANY_REQUESTS', message: 'Too many requests. Please try again later.' }
          }.to_json
          headers = { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s }

          [429, headers, [body]]
        end

        def text_response(retry_after)
          [
            429,
            {
              'Content-Type' => 'text/plain',
              'Retry-After' => retry_after.to_s
            },
            ['Too many requests. Please try again later.']
          ]
        end
      end
    end

    module RackAttack
      DEFAULT_WINDOW = 60
      DEFAULT_LIMIT = 100
      TOKEN_LIMIT = 60

      class << self
        def configure!(rack_attack = ::Rack::Attack)
          rack_attack.cache.store = RackAttackStore.new

          rack_attack.throttle('requests per ip', limit: DEFAULT_LIMIT, period: DEFAULT_WINDOW, &:ip)

          rack_attack.throttle('requests per token', limit: TOKEN_LIMIT, period: DEFAULT_WINDOW) do |req|
            token_from_header(req) || token_from_path(req)
          end

          rack_attack.throttled_response = ->(env) { RackAttackResponse.call(env) }
        end

        private

        def token_from_header(req)
          header = req.get_header('HTTP_AUTHORIZATION')
          return unless header&.start_with?('Bearer ')

          token = header.split(' ', 2)[1]&.strip
          token unless token.nil? || token.empty?
        end

        def token_from_path(req)
          match = req.path.match(%r{^/api/v1/feeds/([^/]+)})
          match && match[1]
        end
      end
    end
  end
end

Html2rss::Web::RackAttack.configure!
