# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/auth'
require_relative '../../../app/security_logger'

RSpec.describe Html2rss::Web::Auth do
  let(:test_config) do
    {
      auth: {
        accounts: [
          {
            username: 'testuser',
            token: 'test-token-abc123',
            allowed_urls: ['https://example.com', 'https://test.com']
          },
          {
            username: 'admin',
            token: 'admin-token-xyz789',
            allowed_urls: ['*']
          }
        ]
      }
    }
  end

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(test_config)
    allow(Html2rss::Web::SecurityLogger).to receive(:log_auth_failure)
    allow(Html2rss::Web::SecurityLogger).to receive(:log_token_usage)
    allow(Html2rss::Web::SecurityLogger).to receive(:log_rate_limit_exceeded)
    allow(Html2rss::Web::SecurityLogger).to receive(:log_blocked_request)
    allow(Html2rss::Web::SecurityLogger).to receive(:log_config_validation_failure)
  end

  describe '.load_accounts' do
    it 'loads accounts from config', :aggregate_failures do
      accounts = described_class.load_accounts

      expect(accounts).to be_an(Array)
      expect(accounts.length).to eq(2)

      expect(accounts[0]).to include(
        username: 'testuser',
        token: 'test-token-abc123',
        allowed_urls: ['https://example.com', 'https://test.com']
      )

      expect(accounts[1]).to include(
        username: 'admin',
        token: 'admin-token-xyz789',
        allowed_urls: ['*']
      )
    end
  end

  describe '.secret_key' do
    it 'returns the environment variable value' do
      expect(described_class.secret_key).to eq('test-secret-key-for-specs')
    end
  end

  describe '.get_account_by_username' do
    it 'returns the correct account for existing username', :aggregate_failures do
      account = described_class.get_account_by_username('testuser')

      expect(account).to include(
        username: 'testuser',
        token: 'test-token-abc123',
        allowed_urls: ['https://example.com', 'https://test.com']
      )
    end

    it 'returns nil for non-existing username' do
      account = described_class.get_account_by_username('nonexistent')
      expect(account).to be_nil
    end
  end

  describe '.generate_feed_id' do
    it 'generates a consistent ID for the same inputs', :aggregate_failures do
      id1 = described_class.generate_feed_id('testuser', 'https://example.com', 'test-token')
      id2 = described_class.generate_feed_id('testuser', 'https://example.com', 'test-token')

      expect(id1).to eq(id2)
      expect(id1).to be_a(String)
      expect(id1.length).to eq(16) # First 16 characters of SHA256
    end

    it 'generates different IDs for different inputs', :aggregate_failures do
      id1 = described_class.generate_feed_id('testuser', 'https://example.com', 'test-token')
      id2 = described_class.generate_feed_id('testuser', 'https://other.com', 'test-token')
      id3 = described_class.generate_feed_id('otheruser', 'https://example.com', 'test-token')

      expect(id1).not_to eq(id2)
      expect(id1).not_to eq(id3)
      expect(id2).not_to eq(id3)
    end
  end

  describe '.generate_feed_token' do
    let(:username) { 'testuser' }
    let(:url) { 'https://example.com' }

    it 'generates a valid token', :aggregate_failures do
      token = described_class.generate_feed_token(username, url)

      expect(token).to be_a(String)
      expect(token).not_to be_empty
    end

    it 'generates different tokens for different inputs', :aggregate_failures do
      token1 = described_class.generate_feed_token('user1', 'https://example.com')
      token2 = described_class.generate_feed_token('user2', 'https://example.com')
      token3 = described_class.generate_feed_token('user1', 'https://other.com')

      expect(token1).not_to eq(token2)
      expect(token1).not_to eq(token3)
      expect(token2).not_to eq(token3)
    end

    it 'uses the default 10-year expiry', :aggregate_failures do
      token = described_class.generate_feed_token(username, url)
      decoded = JSON.parse(Base64.urlsafe_decode64(token), symbolize_names: true)

      expires_at = decoded[:payload][:expires_at]
      current_time = Time.now.to_i
      expected_expiry = current_time + 315_360_000 # 10 years

      expect(expires_at).to be > current_time
      expect(expires_at).to be_within(60).of(expected_expiry) # Within 1 minute
    end

    it 'uses custom expiry when provided', :aggregate_failures do
      custom_expiry = 3600 # 1 hour
      token = described_class.generate_feed_token(username, url, expires_in: custom_expiry)
      decoded = JSON.parse(Base64.urlsafe_decode64(token), symbolize_names: true)

      expires_at = decoded[:payload][:expires_at]
      current_time = Time.now.to_i
      expected_expiry = current_time + custom_expiry

      expect(expires_at).to be_within(60).of(expected_expiry)
    end

    it 'returns nil when secret key is not available' do
      allow(described_class).to receive(:secret_key).and_return(nil)

      token = described_class.generate_feed_token(username, url)
      expect(token).to be_nil
    end

    it 'includes correct payload structure', :aggregate_failures do
      token = described_class.generate_feed_token(username, url)
      decoded = JSON.parse(Base64.urlsafe_decode64(token), symbolize_names: true)

      expect(decoded).to have_key(:payload)
      expect(decoded).to have_key(:signature)

      payload = decoded[:payload]
      expect(payload).to include(
        username: username,
        url: url
      )
      expect(payload).to have_key(:expires_at)
    end
  end

  describe '.validate_feed_token' do
    let(:username) { 'testuser' }
    let(:url) { 'https://example.com' }
    let(:valid_token) { described_class.generate_feed_token(username, url) }

    it 'validates a correct token', :aggregate_failures do
      account = described_class.validate_feed_token(valid_token, url)

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_token_usage).with(valid_token, url, true)
      expect(account).to include(
        username: username,
        token: 'test-token-abc123',
        allowed_urls: ['https://example.com', 'https://test.com']
      )
    end

    it 'returns nil for invalid token' do
      account = described_class.validate_feed_token('invalid-token', url)

      expect(account).to be_nil
    end

    it 'logs token usage for invalid token' do
      described_class.validate_feed_token('invalid-token', url)

      expect(Html2rss::Web::SecurityLogger).to have_received(:log_token_usage).with('invalid-token', url, false)
    end

    it 'returns nil for token with wrong URL' do
      account = described_class.validate_feed_token(valid_token, 'https://wrong.com')
      expect(account).to be_nil
    end

    it 'returns nil for expired token' do
      expired_token = described_class.generate_feed_token(username, url, expires_in: -3600) # 1 hour ago
      account = described_class.validate_feed_token(expired_token, url)
      expect(account).to be_nil
    end

    it 'returns nil for tampered token' do
      # Create a token and modify its payload
      token_data = JSON.parse(Base64.urlsafe_decode64(valid_token), symbolize_names: true)
      token_data[:payload][:username] = 'hacker'
      tampered_token = Base64.urlsafe_encode64(token_data.to_json)

      account = described_class.validate_feed_token(tampered_token, url)
      expect(account).to be_nil
    end

    it 'returns nil for malformed token' do
      account = described_class.validate_feed_token('not-base64', url)
      expect(account).to be_nil
    end

    it 'returns nil when secret key is not available' do
      allow(described_class).to receive(:secret_key).and_return(nil)

      account = described_class.validate_feed_token(valid_token, url)
      expect(account).to be_nil
    end

    it 'handles JSON parsing errors gracefully' do
      invalid_json_token = Base64.urlsafe_encode64('invalid-json')
      account = described_class.validate_feed_token(invalid_json_token, url)
      expect(account).to be_nil
    end
  end

  describe '.extract_feed_token_from_url' do
    it 'extracts token from URL with token parameter' do
      url = 'https://example.com/feeds/123?token=abc123&url=https://source.com'
      token = described_class.extract_feed_token_from_url(url)
      expect(token).to eq('abc123')
    end

    it 'returns nil when no token parameter' do
      url = 'https://example.com/feeds/123?url=https://source.com'
      token = described_class.extract_feed_token_from_url(url)
      expect(token).to be_nil
    end

    it 'handles URLs without query parameters' do
      url = 'https://example.com/feeds/123'
      token = described_class.extract_feed_token_from_url(url)
      expect(token).to be_nil
    end
  end

  describe '.feed_url_allowed?' do
    let(:username) { 'testuser' }
    let(:allowed_url) { 'https://example.com' }
    let(:disallowed_url) { 'https://malicious.com' }
    let(:valid_token) { described_class.generate_feed_token(username, allowed_url) }

    it 'allows access for valid token and allowed URL' do
      result = described_class.feed_url_allowed?(valid_token, allowed_url)
      expect(result).to be true
    end

    it 'denies access for valid token but disallowed URL' do
      result = described_class.feed_url_allowed?(valid_token, disallowed_url)
      expect(result).to be false
    end

    it 'denies access for invalid token' do
      result = described_class.feed_url_allowed?('invalid-token', allowed_url)
      expect(result).to be false
    end

    it 'allows access for admin user with wildcard URLs' do
      admin_token = described_class.generate_feed_token('admin', 'https://any-site.com')
      result = described_class.feed_url_allowed?(admin_token, 'https://any-site.com')
      expect(result).to be true
    end
  end

  describe '.authenticate' do
    let(:valid_token) { 'test-token-abc123' }
    let(:invalid_token) { 'invalid-token' }
    let(:mock_request) do
      instance_double(Rack::Request, env: {}, params: {}, ip: '192.168.1.1', user_agent: 'Mozilla/5.0')
    end

    it 'authenticates with valid token in Authorization header', :aggregate_failures do
      allow(mock_request).to receive(:env).and_return({ 'HTTP_AUTHORIZATION' => "Bearer #{valid_token}" })

      account = described_class.authenticate(mock_request)

      expect(account).to include(
        username: 'testuser',
        token: valid_token,
        allowed_urls: ['https://example.com', 'https://test.com']
      )
    end

    it 'does not authenticate with token in query params', :aggregate_failures do
      allow(mock_request).to receive(:params).and_return({ 'token' => valid_token })

      account = described_class.authenticate(mock_request)

      expect(account).to be_nil
    end

    it 'returns nil for invalid token' do
      allow(mock_request).to receive(:env).and_return({ 'HTTP_AUTHORIZATION' => "Bearer #{invalid_token}" })

      account = described_class.authenticate(mock_request)
      expect(account).to be_nil
    end

    it 'returns nil when no token provided' do
      account = described_class.authenticate(mock_request)
      expect(account).to be_nil
    end
  end

  describe '.url_allowed?' do
    let(:account) { { username: 'testuser', token: 'test-token-abc123', allowed_urls: ['https://example.com', 'https://test.com'] } }

    it 'allows URL that is in allowed_urls' do
      result = described_class.url_allowed?(account, 'https://example.com')
      expect(result).to be true
    end

    it 'denies URL that is not in allowed_urls' do
      result = described_class.url_allowed?(account, 'https://malicious.com')
      expect(result).to be false
    end

    it 'allows any URL for admin user' do
      admin_account = { username: 'admin', token: 'admin-token-xyz789', allowed_urls: ['*'] }
      result = described_class.url_allowed?(admin_account, 'https://any-site.com')
      expect(result).to be true
    end

    it 'returns true for account with no URL restrictions' do
      unrestricted_account = { username: 'unrestricted', token: 'unrestricted-token', allowed_urls: [] }
      result = described_class.url_allowed?(unrestricted_account, 'https://example.com')
      expect(result).to be true
    end
  end

  describe '.valid_username?' do
    it 'accepts valid usernames', :aggregate_failures do
      expect(described_class.valid_username?('user123')).to be true
      expect(described_class.valid_username?('user-name')).to be true
      expect(described_class.valid_username?('user_name')).to be true
      expect(described_class.valid_username?('a')).to be true
    end

    it 'rejects invalid usernames', :aggregate_failures do
      expect(described_class.valid_username?('')).to be false
      expect(described_class.valid_username?('user@domain')).to be false
      expect(described_class.valid_username?('user space')).to be false
      expect(described_class.valid_username?('user+plus')).to be false
      expect(described_class.valid_username?('user.dot')).to be false
      expect(described_class.valid_username?('a' * 101)).to be false
      expect(described_class.valid_username?(nil)).to be false
      expect(described_class.valid_username?(123)).to be false
    end
  end

  describe '.secure_compare' do
    it 'compares equal strings correctly', :aggregate_failures do
      expect(described_class.secure_compare('test', 'test')).to be true
      expect(described_class.secure_compare('', '')).to be true
      expect(described_class.secure_compare('a', 'a')).to be true
    end

    it 'compares different strings correctly', :aggregate_failures do
      expect(described_class.secure_compare('test', 'different')).to be false
      expect(described_class.secure_compare('test', 'tes')).to be false
      expect(described_class.secure_compare('tes', 'test')).to be false
      expect(described_class.secure_compare('test', '')).to be false
      expect(described_class.secure_compare('', 'test')).to be false
    end

    it 'handles nil inputs', :aggregate_failures do
      expect(described_class.secure_compare(nil, 'test')).to be false
      expect(described_class.secure_compare('test', nil)).to be false
      expect(described_class.secure_compare(nil, nil)).to be false
    end

    it 'prevents timing attacks with different length strings' do
      # This test ensures that the method doesn't short-circuit on length differences
      start_time = Time.now
      described_class.secure_compare('a', 'ab')
      short_time = Time.now - start_time

      start_time = Time.now
      described_class.secure_compare('a', 'a')
      equal_time = Time.now - start_time

      # Both should take similar time (within 1ms tolerance for test environment)
      expect((equal_time - short_time).abs).to be < 0.001
    end
  end

  describe 'token length validation' do
    it 'rejects empty tokens' do
      mock_request = instance_double(Rack::Request, env: { 'HTTP_AUTHORIZATION' => 'Bearer ' }, ip: '192.168.1.1',
                                                    user_agent: 'Mozilla/5.0')
      account = described_class.authenticate(mock_request)
      expect(account).to be_nil
    end

    it 'rejects tokens that are too long' do
      long_token = 'a' * 1025
      mock_request = instance_double(Rack::Request, env: { 'HTTP_AUTHORIZATION' => "Bearer #{long_token}" },
                                                    ip: '192.168.1.1', user_agent: 'Mozilla/5.0')
      account = described_class.authenticate(mock_request)
      expect(account).to be_nil
    end

    it 'accepts tokens within length limits' do
      valid_token = 'test-token-abc123'
      mock_request = instance_double(Rack::Request, env: { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token}" },
                                                    ip: '192.168.1.1', user_agent: 'Mozilla/5.0')
      account = described_class.authenticate(mock_request)
      expect(account).to include(username: 'testuser')
    end
  end

  describe 'security edge cases' do
    it 'prevents timing attacks on token validation' do
      # Test that invalid tokens take similar time to process
      valid_token = 'test-token-abc123'
      invalid_token = 'invalid-token-xyz'

      valid_request = instance_double(Rack::Request, env: { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token}" },
                                                     ip: '192.168.1.1', user_agent: 'Mozilla/5.0')
      invalid_request = instance_double(Rack::Request, env: { 'HTTP_AUTHORIZATION' => "Bearer #{invalid_token}" },
                                                       ip: '192.168.1.1', user_agent: 'Mozilla/5.0')

      start_time = Time.now
      described_class.authenticate(valid_request)
      valid_time = Time.now - start_time

      start_time = Time.now
      described_class.authenticate(invalid_request)
      invalid_time = Time.now - start_time

      # Both should take similar time (within 5ms tolerance)
      expect((valid_time - invalid_time).abs).to be < 0.005
    end

    it 'handles malformed authorization headers' do
      malformed_requests = [
        { 'HTTP_AUTHORIZATION' => 'InvalidFormat' },
        { 'HTTP_AUTHORIZATION' => 'Bearer' },
        { 'HTTP_AUTHORIZATION' => 'Bearer ' },
        { 'HTTP_AUTHORIZATION' => 'Basic dGVzdA==' },
        { 'HTTP_AUTHORIZATION' => nil }
      ]

      malformed_requests.each do |env|
        mock_request = instance_double(Rack::Request, env: env, ip: '127.0.0.1', user_agent: 'test-agent')
        account = described_class.authenticate(mock_request)
        expect(account).to be_nil
      end
    end

    it 'rejects tokens with special characters' do
      malicious_tokens = [
        "test-token'; DROP TABLE users; --",
        'test-token<script>alert("xss")</script>',
        'test-token" OR "1"="1',
        "test-token\x00null",
        'test-token\n\r\t'
      ]

      malicious_tokens.each do |token|
        mock_request = instance_double(Rack::Request, env: { 'HTTP_AUTHORIZATION' => "Bearer #{token}" },
                                                      ip: '192.168.1.1', user_agent: 'Mozilla/5.0')
        account = described_class.authenticate(mock_request)
        expect(account).to be_nil
      end
    end

    it 'handles extremely long usernames in feed tokens' do
      long_username = 'a' * 101
      url = 'https://example.com'

      token = described_class.generate_feed_token(long_username, url)
      expect(token).to be_nil
    end

    it 'rejects malformed feed tokens' do
      malformed_tokens = [
        'not-base64',
        Base64.urlsafe_encode64('invalid-json'),
        Base64.urlsafe_encode64('{"invalid": "structure"}'),
        Base64.urlsafe_encode64('{"payload": {}, "signature": ""}'),
        ''
      ]

      malformed_tokens.each do |token|
        account = described_class.validate_feed_token(token, 'https://example.com')
        expect(account).to be_nil
      end
    end
  end
end
