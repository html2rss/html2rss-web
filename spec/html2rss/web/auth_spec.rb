# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'

RSpec.describe Html2rss::Web::Auth do
  let(:account) { { username: 'alice', token: 'tok' } }
  let(:context) do
    Html2rss::Web::RequestContext::Context.new(
      request_id: 'r', path: '/', http_method: 'GET', route_group: 'x', actor: nil, strategy: nil,
      started_at: Time.now, monotonic_start: 0
    )
  end

  def request_with(header = nil, ip: '10.1.1.1')
    env = Rack::MockRequest.env_for('/', 'REMOTE_ADDR' => ip, 'HTTP_USER_AGENT' => 'ua')
    env['HTTP_AUTHORIZATION'] = header if header
    Rack::Request.new(env)
  end

  before do
    allow(Html2rss::Web::AccountManager).to receive(:get_account).and_return(nil)
    allow(Html2rss::Web::AccountManager).to receive(:get_account).with('tok').and_return(account)
    allow(Html2rss::Web::Observability).to receive(:emit)
    allow(Html2rss::Web::SecurityLogger).to receive(:log_auth_failure)
    allow(Html2rss::Web::SecurityLogger).to receive(:log_auth_success)
    Html2rss::Web::RequestContext.clear!
  end

  after { Html2rss::Web::RequestContext.clear! }

  describe '.extract_token' do
    it 'extracts the bearer token' do
      expect(described_class.extract_token(request_with('Bearer abc'))).to eq('abc')
    end

    it 'rejects a missing header, other schemes and a bare prefix', :aggregate_failures do
      expect(described_class.extract_token(request_with)).to be_nil
      expect(described_class.extract_token(request_with('Basic abc'))).to be_nil
      expect(described_class.extract_token(request_with('bearer abc'))).to be_nil
      expect(described_class.extract_token(request_with('Bearer'))).to be_nil
      expect(described_class.extract_token(request_with('Bearer '))).to be_nil
    end

    it 'accepts tokens up to 1024 characters and rejects longer ones', :aggregate_failures do
      expect(described_class.extract_token(request_with("Bearer #{'a' * 1024}"))).to eq('a' * 1024)
      expect(described_class.extract_token(request_with("Bearer #{'a' * 1025}"))).to be_nil
    end
  end

  describe '.authenticate' do
    it 'returns the account and audits success', :aggregate_failures do
      expect(described_class.authenticate(request_with('Bearer tok'))).to eq(account)
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'auth.authenticate', outcome: 'success', details: { username: 'alice' }, level: :info
      )
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_auth_success).with('alice', '10.1.1.1')
    end

    it 'sets the request context actor on success' do
      Html2rss::Web::RequestContext.set!(context)
      described_class.authenticate(request_with('Bearer tok'))

      expect(Html2rss::Web::RequestContext.current.actor).to eq('alice')
    end

    it 'does not create a request context when none exists' do
      described_class.authenticate(request_with('Bearer tok'))

      expect(Html2rss::Web::RequestContext.current).to be_nil
    end

    it 'does not set an actor when the account has no username' do
      allow(Html2rss::Web::AccountManager).to receive(:get_account).with('tok').and_return({ token: 'tok' })
      Html2rss::Web::RequestContext.set!(context)
      described_class.authenticate(request_with('Bearer tok'))

      expect(Html2rss::Web::RequestContext.current.actor).to be_nil
    end

    it 'audits a missing token', :aggregate_failures do
      expect(described_class.authenticate(request_with)).to be_nil
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'auth.authenticate', outcome: 'failure', details: { reason: 'missing_token' }, level: :warn
      )
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_auth_failure).with('10.1.1.1', 'ua', 'missing_token')
    end

    it 'audits an unknown token', :aggregate_failures do
      expect(described_class.authenticate(request_with('Bearer nope'))).to be_nil
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'auth.authenticate', outcome: 'failure', details: { reason: 'invalid_token' }, level: :warn
      )
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_auth_failure).with('10.1.1.1', 'ua', 'invalid_token')
    end
  end

  describe 'feed tokens' do
    before { allow(Html2rss::Web::RuntimeEnv).to receive(:secret_key).and_return('secret') }

    it 'round-trips a generated token with its url and strategy', :aggregate_failures do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_token_usage)
      encoded = described_class.generate_feed_token('alice', 'https://example.com/f', strategy: 'faraday')
      token = described_class.validate_and_decode_feed_token(encoded)

      expect(token).to have_attributes(username: 'alice', url: 'https://example.com/f', strategy: 'faraday')
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_token_usage).with(encoded, 'https://example.com/f',
                                                                                    true)
    end

    it 'honours expires_in', :aggregate_failures do
      encoded = described_class.generate_feed_token('alice', 'https://example.com/f', expires_in: 60)
      decoded = Html2rss::Web::FeedToken::Codec.decode(encoded)

      expect(decoded.expires_at).to be_within(2).of(Time.now.to_i + 60)
    end

    it 'defaults to the long-lived expiry' do
      decoded = Html2rss::Web::FeedToken::Codec.decode(described_class.generate_feed_token('alice', 'https://example.com/f'))

      expect(decoded.expires_at).to be_within(2).of(Time.now.to_i + Html2rss::Web::FeedToken::DEFAULT_EXPIRY)
    end

    it 'returns nil for invalid generation input' do
      expect(described_class.generate_feed_token('', 'https://example.com/f')).to be_nil
    end

    it 'returns nil for undecodable tokens without logging usage' do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_token_usage)

      expect(described_class.validate_and_decode_feed_token('garbage')).to be_nil
      expect(Html2rss::Web::SecurityLogger).not_to have_received(:log_token_usage)
    end

    it 'rejects tokens signed with another secret and logs the failure', :aggregate_failures do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_token_usage)
      encoded = described_class.generate_feed_token('alice', 'https://example.com/f')
      allow(Html2rss::Web::RuntimeEnv).to receive(:secret_key).and_return('other')

      expect(described_class.validate_and_decode_feed_token(encoded)).to be_nil
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_token_usage).with(encoded, 'https://example.com/f',
                                                                                    false)
    end

    it 'assigns the strategy to the request context only when present', :aggregate_failures do
      Html2rss::Web::RequestContext.set!(context)
      described_class.validate_and_decode_feed_token(described_class.generate_feed_token('alice', 'https://example.com/f'))
      expect(Html2rss::Web::RequestContext.current.strategy).to be_nil

      described_class.validate_and_decode_feed_token(
        described_class.generate_feed_token('alice', 'https://example.com/f', strategy: 'faraday')
      )
      expect(Html2rss::Web::RequestContext.current.strategy).to eq('faraday')
    end
  end
end
