# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Rack::Attack' do
  before do
    require 'rack/attack'
    require_relative '../../../config/rack_attack'
  end

  it 'loads configuration without errors' do
    expect { require_relative '../../../config/rack_attack' }.not_to raise_error
  end

  it 'has a configured cache store' do
    expect(Rack::Attack.cache.store).not_to be_nil
  end

  it 'has rate limiting rules configured' do
    expect(Rack::Attack.throttles).not_to be_empty
  end

  it 'has safelist rules configured' do
    expect(Rack::Attack.safelists).not_to be_empty
  end

  it 'has blocklist rules configured' do
    expect(Rack::Attack.blocklists).not_to be_empty
  end

  it 'has throttled response handler' do
    expect(Rack::Attack.throttled_response).to be_a(Proc)
  end

  it 'has blocklisted response handler' do
    expect(Rack::Attack.blocklisted_response).to be_a(Proc)
  end

  describe 'safelist rules' do
    it 'has health-check safelist configured' do
      expect(Rack::Attack.safelists).to have_key('health-check')
    end

    it 'has localhost safelist configured' do
      expect(Rack::Attack.safelists).to have_key('localhost')
    end
  end

  describe 'throttle rules' do
    it 'has IP-based throttling configured' do
      expect(Rack::Attack.throttles).to have_key('requests per IP')
    end

    it 'has API throttling configured' do
      expect(Rack::Attack.throttles).to have_key('api requests per IP')
    end

    it 'has feed generation throttling configured' do
      expect(Rack::Attack.throttles).to have_key('feed generation per IP')
    end
  end

  describe 'blocklist rules' do
    it 'has user agent blocklist configured' do
      expect(Rack::Attack.blocklists).to have_key('block bad user agents')
    end
  end

  describe 'response handlers' do
    let(:env) { {} }

    it 'returns proper throttled response status' do
      response = Rack::Attack.throttled_response.call(env)
      expect(response[0]).to eq(429)
    end

    it 'returns proper throttled response content type' do
      response = Rack::Attack.throttled_response.call(env)
      expect(response[1]['Content-Type']).to eq('application/xml')
    end

    it 'returns proper throttled response retry after header' do
      response = Rack::Attack.throttled_response.call(env)
      expect(response[1]['Retry-After']).to eq('60')
    end

    it 'returns proper throttled response rate limit limit header' do
      response = Rack::Attack.throttled_response.call(env)
      expect(response[1]).to have_key('X-RateLimit-Limit')
    end

    it 'returns proper throttled response rate limit remaining header' do
      response = Rack::Attack.throttled_response.call(env)
      expect(response[1]).to have_key('X-RateLimit-Remaining')
    end

    it 'returns proper throttled response rate limit reset header' do
      response = Rack::Attack.throttled_response.call(env)
      expect(response[1]).to have_key('X-RateLimit-Reset')
    end

    it 'returns proper blocklisted response status' do
      response = Rack::Attack.blocklisted_response.call(env)
      expect(response[0]).to eq(403)
    end

    it 'returns proper blocklisted response headers' do
      response = Rack::Attack.blocklisted_response.call(env)
      expect(response[1]['Content-Type']).to eq('application/xml')
    end
  end
end
