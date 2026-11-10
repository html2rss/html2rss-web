# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'
require 'climate_control'

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
      # rubocop:disable Naming/VariableNumber
      remaining_keys_1 = perform_overflow_eviction.call
      remaining_keys_2 = perform_overflow_eviction.call
      # rubocop:enable Naming/VariableNumber
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
  end

  describe described_class::RequestTrack do
    subject(:track) { described_class.new }

    it 'allows exactly max_requests within the window', :aggregate_failures do
      expect(track.record_and_check_limit(100, 10, 2)).to eq([false, 0])
      expect(track.record_and_check_limit(101, 10, 2)).to eq([false, 0])
      expect(track.record_and_check_limit(102, 10, 2)).to eq([true, 8])
    end

    it 'consumes cost slots per request', :aggregate_failures do
      expect(track.record_and_check_limit(100, 10, 5, cost: 5)).to eq([false, 0])
      expect(track.record_and_check_limit(101, 10, 5)).to eq([true, 9])
    end

    it 'blocks once a costed request overshoots the budget', :aggregate_failures do
      expect(track.record_and_check_limit(100, 10, 3, cost: 5)).to eq([false, 0])
      expect(track.record_and_check_limit(101, 10, 3)).to eq([true, 9])
    end

    it 'keeps timestamps exactly at the window start and drops older ones', :aggregate_failures do
      track.record_and_check_limit(100, 10, 1)

      expect(track.record_and_check_limit(110, 10, 1)).to eq([true, 1])
      expect(track.record_and_check_limit(111, 10, 1)).to eq([false, 0])
    end

    it 'reports at least one second of retry_after' do
      track.record_and_check_limit(100, 10, 1)

      expect(track.record_and_check_limit(110, 10, 1).last).to eq(1)
    end

    it 'does not record rejected requests', :aggregate_failures do
      track.record_and_check_limit(100, 10, 1)
      expect(track.record_and_check_limit(101, 10, 1)).to eq([true, 9])

      expect(track.record_and_check_limit(111, 10, 1)).to eq([false, 0])
    end

    it 'prune drops expired entries and removes empty tracks from history', :aggregate_failures do
      history = { 'a' => track, 'b' => described_class.new }
      track.record_and_check_limit(100, 10, 5)
      track.record_and_check_limit(105, 10, 5)

      track.prune(100, history, 'a')
      expect(history).to have_key('a')
      track.prune(106, history, 'a')
      expect(history).not_to have_key('a')
      expect(history).to have_key('b')
    end
  end

  describe 'request handling' do
    let(:now) { Time.now.to_i }

    it 'tracks clients independently by IP', :aggregate_failures do
      3.times { request_builder.get('/api/v1/feeds', 'REMOTE_ADDR' => '10.0.0.1') }

      expect(request_builder.get('/api/v1/feeds', 'REMOTE_ADDR' => '10.0.0.1').status).to eq(429)
      expect(request_builder.get('/api/v1/feeds', 'REMOTE_ADDR' => '10.0.0.2').status).to eq(200)
    end

    it 'bypasses health sub-paths but not look-alike paths', :aggregate_failures do
      4.times { expect(request_builder.get('/api/v1/health/ready').status).to eq(200) }
      4.times { request_builder.get('/api/v1/healthy') }
      expect(request_builder.get('/api/v1/healthy').status).to eq(429)
    end

    it 'does not bypass look-alike asset paths', :aggregate_failures do
      4.times { request_builder.get('/assetsx/logo.png') }
      expect(request_builder.get('/assetsx/logo.png').status).to eq(429)
    end

    it 'logs the client key, path and configured maximum' do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_rate_limit_exceeded)
      4.times { request_builder.get('/api/v1/feeds', 'REMOTE_ADDR' => '10.0.0.9') }

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_rate_limit_exceeded).with('10.0.0.9', anything, 3)
    end

    it 'marks feed and non-api paths as feed requests but not other api paths', :aggregate_failures do
      env_for = lambda do |path|
        env = Rack::MockRequest.env_for(path)
        3.times { middleware.call(Rack::MockRequest.env_for(path)) }
        middleware.call(env)
        env[Html2rss::Web::RequestTarget::ENV_KEY]
      end

      expect(env_for.call('/api/v1/feeds/abc')).to eq(Html2rss::Web::RequestTarget::FEED)
      expect(env_for.call('/somewhere')).to eq(Html2rss::Web::RequestTarget::FEED)
      expect(env_for.call('/api/v1/other')).not_to eq(Html2rss::Web::RequestTarget::FEED)
    end

    it 'does not prune at exactly 1000 entries', :aggregate_failures do
      history = middleware.instance_variable_get(:@history)
      1000.times { |i| history["ip-#{i}"] = described_class::RequestTrack.new }
      request_builder.get('/api/v1/feeds')

      expect(history.size).to eq(1001)
    end

    it 'throttles pruning to once every 10 seconds', :aggregate_failures do
      history = middleware.instance_variable_get(:@history)
      allow(Time).to receive(:now).and_return(Time.at(now))
      1005.times { |i| history["ip-#{i}"] = described_class::RequestTrack.new }
      request_builder.get('/api/v1/feeds')
      expect(history.size).to eq(1)

      1005.times { |i| history["ip-#{i}"] = described_class::RequestTrack.new }
      allow(Time).to receive(:now).and_return(Time.at(now + 10))
      request_builder.get('/api/v1/feeds')
      expect(history.size).to eq(1006)

      allow(Time).to receive(:now).and_return(Time.at(now + 11))
      request_builder.get('/api/v1/feeds')
      expect(history.size).to eq(1)
    end

    it 'does not log overflow when expiry prunes history to the cap', :aggregate_failures do
      history = middleware.instance_variable_get(:@history)
      20_001.times { |i| history["ip-#{i}"] = described_class::RequestTrack.new }
      allow(Html2rss::Web::SecurityLogger).to receive(:log_suspicious_activity)
      request_builder.get('/api/v1/feeds')

      expect(Html2rss::Web::SecurityLogger).not_to have_received(:log_suspicious_activity)
      expect(history.size).to eq(1)
    end

    it 'forwards the original env to the app when bypassing or disabled', :aggregate_failures do
      seen = []
      app = lambda do |env|
        seen << env
        [200, {}, ['ok']]
      end
      limiter = described_class.new(app)
      env = Rack::MockRequest.env_for('/assets/x.png')
      limiter.call(env)
      allow(Html2rss::Web::Flags).to receive(:rate_limit_enabled?).and_return(false)
      limiter.call(env)

      expect(seen).to all(equal(env))
    end

    it 'reports the remaining window in Retry-After, not the full window', :aggregate_failures do
      allow(Time).to receive(:now).and_return(Time.at(now))
      3.times { request_builder.get('/api/v1/feeds') }
      allow(Time).to receive(:now).and_return(Time.at(now + 4))
      response = request_builder.get('/api/v1/feeds')

      expect(response.status).to eq(429)
      expect(response['Retry-After']).to eq('6')
    end

    it 'keeps live tracks when pruning expired ones', :aggregate_failures do
      history = middleware.instance_variable_get(:@history)
      allow(Time).to receive(:now).and_return(Time.at(now))
      live = described_class::RequestTrack.new
      live.record_and_check_limit(now - 5, 10, 3)
      history['live'] = live
      1004.times { |i| history["idle-#{i}"] = described_class::RequestTrack.new }
      request_builder.get('/api/v1/feeds')

      expect(history.size).to eq(2)
      expect(history).to have_key('live')
    end

    # rubocop:disable RSpec/ExampleLength
    it 'logs overflow only when the post-prune size exceeds the cap', :aggregate_failures do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_suspicious_activity)
      fill = lambda do |count, expired: 0|
        h = described_class.new(inner_app)
        hist = h.instance_variable_get(:@history)
        count.times do |i|
          t = described_class::RequestTrack.new
          t.record_and_check_limit(Time.now.to_i, 10, 3) if i >= expired
          hist["ip-#{i}"] = t
        end
        h
      end

      fill.call(20_001, expired: 1).send(:prune_history_if_needed)
      expect(Html2rss::Web::SecurityLogger).not_to have_received(:log_suspicious_activity)
      fill.call(20_001).send(:prune_history_if_needed)
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_suspicious_activity).once
    end

    it 'does not evict when overflow equals the cap after pruning', :aggregate_failures do
      history = middleware.instance_variable_get(:@history)
      20_000.times do |i|
        t = described_class::RequestTrack.new
        t.record_and_check_limit(Time.now.to_i, 10, 3)
        history["ip-#{i}"] = t
      end
      allow(Html2rss::Web::SecurityLogger).to receive(:log_suspicious_activity)
      request_builder.get('/api/v1/feeds')

      expect(Html2rss::Web::SecurityLogger).not_to have_received(:log_suspicious_activity)
      expect(history.size).to eq(20_001)
    end
    # rubocop:enable RSpec/ExampleLength
  end
end
