# frozen_string_literal: true

require 'rack/attack'

# In-memory store (resets on restart)
# Note: In production, consider using Redis for persistent rate limiting
Rack::Attack.cache.store = {}

# Whitelist health checks and internal IPs
Rack::Attack.safelist('health-check') do |req|
  req.path.start_with?('/health', '/status')
end

# Whitelist localhost in development
Rack::Attack.safelist('localhost') do |req|
  %w[127.0.0.1 ::1].include?(req.ip) if ENV['RACK_ENV'] == 'development'
end

# Rate limiting by IP
Rack::Attack.throttle('requests per IP', limit: 100, period: 60, &:ip)

# Rate limiting for API endpoints
Rack::Attack.throttle('api requests per IP', limit: 200, period: 60) do |req|
  req.ip if req.path.start_with?('/api/')
end

# Rate limiting for feed generation (more restrictive)
Rack::Attack.throttle('feed generation per IP', limit: 10, period: 60) do |req|
  req.ip if req.path.include?('/feeds/')
end

# Block suspicious patterns
Rack::Attack.blocklist('block bad user agents') do |req|
  req.user_agent&.match?(/bot|crawler|spider/i) && !req.user_agent&.match?(/googlebot|bingbot/i)
end

# Custom responses with proper headers
Rack::Attack.throttled_response = lambda do |_env|
  retry_after = 60
  [
    429,
    {
      'Content-Type' => 'application/xml',
      'Retry-After' => retry_after.to_s,
      'X-RateLimit-Limit' => '100',
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (Time.now + retry_after).to_i.to_s
    },
    ['<rss><channel><title>Rate Limited</title><description>Too many requests. ' \
     'Please try again later.</description></channel></rss>']
  ]
end

# Track blocked requests for monitoring
Rack::Attack.blocklisted_response = lambda do |_env|
  [
    403,
    { 'Content-Type' => 'application/xml' },
    ['<rss><channel><title>Access Denied</title><description>Request blocked by ' \
     'security policy.</description></channel></rss>']
  ]
end
