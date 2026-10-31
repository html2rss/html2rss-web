# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::SecurityLogger do
  before { allow(Html2rss::Web::LogEvent).to receive(:emit) }

  def expect_emitted(event_name, details, level)
    expect(Html2rss::Web::LogEvent).to have_received(:emit).with(level:, payload: { event_name:, details: })
  end

  describe '.log_auth_failure' do
    it 'warns with ip, user agent and reason' do
      described_class.log_auth_failure('1.1.1.1', 'ua', 'invalid_token')

      expect_emitted('auth_failure', { ip: '1.1.1.1', user_agent: 'ua', reason: 'invalid_token' }, :warn)
    end
  end

  describe '.log_auth_success' do
    it 'informs with username and ip' do
      described_class.log_auth_success('alice', '1.1.1.1')

      expect_emitted('auth_success', { username: 'alice', ip: '1.1.1.1' }, :info)
    end
  end

  describe '.log_rate_limit_exceeded' do
    it 'warns with ip, endpoint and limit' do
      described_class.log_rate_limit_exceeded('1.1.1.1', '/api/v1/feeds', 3)

      expect_emitted('rate_limit_exceeded', { ip: '1.1.1.1', endpoint: '/api/v1/feeds', limit: 3 }, :warn)
    end
  end

  describe '.log_token_usage' do
    let(:hash) { Digest::SHA256.hexdigest('secret-token')[0..7] }

    it 'logs successful usage at info with a truncated token hash, never the token', :aggregate_failures do
      described_class.log_token_usage('secret-token', 'https://example.com/', true)

      expect_emitted('token_usage', { success: true, url: 'https://example.com/', token_hash: hash }, :info)
      expect(hash.length).to eq(8)
    end

    it 'logs failed usage at warn' do
      described_class.log_token_usage('secret-token', 'https://example.com/', false)

      expect_emitted('token_usage', { success: false, url: 'https://example.com/', token_hash: hash }, :warn)
    end
  end

  describe '.log_suspicious_activity' do
    it 'merges details into the payload at warn' do
      described_class.log_suspicious_activity('system', 'overflow', { size: 5 })

      expect_emitted('suspicious_activity', { ip: 'system', activity: 'overflow', size: 5 }, :warn)
    end

    it 'defaults to no extra details' do
      described_class.log_suspicious_activity('1.1.1.1', 'probe')

      expect_emitted('suspicious_activity', { ip: '1.1.1.1', activity: 'probe' }, :warn)
    end
  end
end
