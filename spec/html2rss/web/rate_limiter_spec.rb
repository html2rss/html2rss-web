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

  it 'does not bypass rate limiting for path traversal attempts' do
    3.times { request_builder.get('/assets/../api/v1/feeds') }
    response = request_builder.get('/assets/../api/v1/feeds')
    expect(response.status).to eq(429)
  end

  context 'when under memory pressure or rate limit breaches' do
    # rubocop:disable RSpec/ExampleLength
    it 'prunes to limit on overflow to prevent OOM', :aggregate_failures do
      history_map = middleware.instance_variable_get(:@history)
      now = Time.now.to_i
      20_005.times do |i|
        track = described_class::RequestTrack.new
        track.instance_variable_set(:@timestamps, [now])
        history_map["192.168.1.#{i}"] = track
      end
      expect(history_map.size).to eq(20_005)

      allow(Html2rss::Web::SecurityLogger).to receive(:log_suspicious_activity)
      request_builder.get('/api/v1/feeds')

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_suspicious_activity).with(
        'system', 'rate_limiter_history_overflow', hash_including(size: 20_005, action: 'prune_to_limit')
      )
      # Should prune down to 10,000 plus the active client request track = 10,001
      expect(history_map.size).to eq(10_001)
    end

    it 'evicts keys randomly on overflow' do
      history_map = middleware.instance_variable_get(:@history)
      now = Time.now.to_i

      # Helper to fill history and trigger overflow
      perform_overflow_eviction = lambda do
        history_map.clear
        20_100.times do |i|
          track = described_class::RequestTrack.new
          track.instance_variable_set(:@timestamps, [now])
          history_map["ip-#{i}"] = track
        end
        middleware.send(:handle_overflow, now)
        history_map.keys.sort
      end

      remaining_keys_1 = perform_overflow_eviction.call
      remaining_keys_2 = perform_overflow_eviction.call

      expect(remaining_keys_1).not_to eq(remaining_keys_2)
    end
    # rubocop:enable RSpec/ExampleLength

    it 'logs rate limit exceeded events to SecurityLogger' do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_rate_limit_exceeded)

      4.times { request_builder.get('/api/v1/feeds') }

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_rate_limit_exceeded).with(
        anything, '/api/v1/feeds', 3
      )
    end

    it 'skips pruning locked tracks using non-blocking try_lock' do
      history_map = middleware.instance_variable_get(:@history)
      track = described_class::RequestTrack.new
      history_map['999.999.999.999'] = track

      # Stub try_lock to return false, mimicking lock contention
      allow(track.instance_variable_get(:@mutex)).to receive(:try_lock).and_return(false)

      # Populate history past 1000 so pruning is triggered
      1005.times do |i|
        history_map["192.168.1.#{i}"] = described_class::RequestTrack.new
      end

      request_builder.get('/api/v1/feeds')

      # Check that the locked track was NOT pruned/deleted, even though it was empty
      expect(history_map.key?('999.999.999.999')).to be(true)
    end

    it 'recovers and retries when a track is deleted during check' do
      track = described_class::RequestTrack.new
      track.instance_variable_set(:@deleted, true)

      call_count = 0
      original_new = described_class::RequestTrack.method(:new)
      allow(described_class::RequestTrack).to receive(:new) do
        call_count += 1
        call_count == 1 ? track : original_new.call
      end

      response = request_builder.get('/api/v1/feeds')
      expect(response.status).to eq(200)
      expect(call_count).to eq(2)
    end
  end
end
