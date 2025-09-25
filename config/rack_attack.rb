# frozen_string_literal: true

require 'json'
require 'rack/attack'
require_relative '../app/security_logger'

# In-memory store (resets on restart)
# Note: In production, consider using Redis for persistent rate limiting
Rack::Attack.cache.store = {}

STANDARD_WINDOW = 60
STANDARD_LIMIT = 100
TOKEN_LIMIT = 60

Rack::Attack.throttle('requests per ip', limit: STANDARD_LIMIT, period: STANDARD_WINDOW, &:ip)

token_from_header = lambda do |req|
  header = req.get_header('HTTP_AUTHORIZATION')
  next unless header&.start_with?('Bearer ')

  token = header.split(' ', 2)[1]&.strip
  token unless token.nil? || token.empty?
end

token_from_path = lambda do |req|
  match = req.path.match(%r{^/api/v1/feeds/([^/]+)})
  match && match[1]
end

Rack::Attack.throttle('requests per token', limit: TOKEN_LIMIT, period: STANDARD_WINDOW) do |req|
  token_from_header.call(req) || token_from_path.call(req)
end

Rack::Attack.throttled_response = lambda do |env|
  Html2rss::Web::RackAttackResponse.call(env)
end

module Html2rss
  module Web
    module RackAttackResponse
      module_function

      def call(env)
        request = Rack::Request.new(env)
        match_data = env['rack.attack.match_data'] || {}
        limit = match_data[:limit] || STANDARD_LIMIT

        Html2rss::Web::SecurityLogger.log_rate_limit_exceeded(request.ip, request.path, limit)

        retry_after = STANDARD_WINDOW
        return api_response(retry_after) if request.path.start_with?('/api/')

        text_response(retry_after)
      end

      def api_response(retry_after)
        body = {
          success: false,
          error: { code: 'TOO_MANY_REQUESTS', message: 'Too many requests. Please try again later.' }
        }.to_json

        [
          429,
          {
            'Content-Type' => 'application/json',
            'Retry-After' => retry_after.to_s
          },
          [body]
        ]
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
end
