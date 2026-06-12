# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'
require 'climate_control'
require_relative '../../../app'

RSpec.describe Html2rss::Web::RateLimiter do
  let(:inner_app) { ->(_env) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }
  let(:middleware) { described_class.new(inner_app) }
  let(:request_builder) { Rack::MockRequest.new(middleware) }

  before do
    allow(Html2rss::Web::Flags).to receive_messages(
      rate_limit_enabled?: true,
      rate_limit_max_requests: 3,
      rate_limit_window_seconds: 10
    )
  end

  it 'allows requests under the limit' do
    3.times do
      response = request_builder.get('/api/v1/feeds')
      expect(response.status).to eq(200)
      expect(response.body).to eq('ok')
    end
  end

  it 'returns 429 and Retry-After header when limit is exceeded', :aggregate_failures do
    3.times { request_builder.get('/api/v1/feeds') }

    response = request_builder.get('/api/v1/feeds')
    expect(response.status).to eq(429)
    expect(response['Retry-After']).to eq('10')
    expect(response['Content-Type']).to eq('application/json')

    body = JSON.parse(response.body)
    expect(body['success']).to be(false)
    expect(body.dig('error', 'code')).to eq('TOO_MANY_REQUESTS')
  end

  it 'bypasses rate limiting for health check routes' do
    4.times do
      response = request_builder.get('/api/v1/health')
      expect(response.status).to eq(200)
    end
  end

  it 'bypasses rate limiting for static assets' do
    4.times do
      response = request_builder.get('/assets/logo.png')
      expect(response.status).to eq(200)
    end
  end

  it 'bypasses rate limiting for root path' do
    4.times do
      response = request_builder.get('/')
      expect(response.status).to eq(200)
    end
  end

  it 'can be disabled via Flags' do
    allow(Html2rss::Web::Flags).to receive(:rate_limit_enabled?).and_return(false)
    4.times do
      response = request_builder.get('/api/v1/feeds')
      expect(response.status).to eq(200)
    end
  end

  it 'prunes history when map size exceeds limit' do
    history_map = middleware.instance_variable_get(:@history)
    1005.times do |i|
      history_map["192.168.1.#{i}"] = described_class::RequestTrack.new
    end

    expect(history_map.size).to eq(1005)

    request_builder.get('/api/v1/feeds')

    expect(history_map.size).to eq(1)
  end
end
