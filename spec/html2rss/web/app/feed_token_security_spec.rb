# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app/auth'

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
    allow(Html2rss::Web::LocalConfig).to receive(:yaml).and_return(test_config)
  end

  describe 'Token Tampering Protection' do
    let(:username) { 'testuser' }
    let(:url) { 'https://example.com' }
    let(:valid_token) { described_class.generate_feed_token(username, url) }

    it 'rejects tokens with modified payload' do
      # Decode and modify the token
      token_data = JSON.parse(Base64.urlsafe_decode64(valid_token), symbolize_names: true)
      token_data[:payload][:username] = 'hacker'
      token_data[:payload][:url] = 'https://malicious.com'
      tampered_token = Base64.urlsafe_encode64(token_data.to_json)

      result = described_class.validate_feed_token(tampered_token, url)
      expect(result).to be_nil
    end

    it 'rejects tokens with modified expiration' do
      # Decode and modify the token
      token_data = JSON.parse(Base64.urlsafe_decode64(valid_token), symbolize_names: true)
      token_data[:payload][:expires_at] = Time.now.to_i + 3600 # 1 hour from now
      tampered_token = Base64.urlsafe_encode64(token_data.to_json)

      result = described_class.validate_feed_token(tampered_token, url)
      expect(result).to be_nil
    end

    it 'rejects tokens with modified signature' do
      # Decode and modify the signature
      token_data = JSON.parse(Base64.urlsafe_decode64(valid_token), symbolize_names: true)
      token_data[:signature] = 'fake-signature'
      tampered_token = Base64.urlsafe_encode64(token_data.to_json)

      result = described_class.validate_feed_token(tampered_token, url)
      expect(result).to be_nil
    end

    it 'rejects completely malformed tokens' do
      malformed_tokens = [
        'not-base64',
        'invalid-json',
        '{"invalid": "structure"}',
        '',
        nil
      ]

      malformed_tokens.each do |token|
        result = described_class.validate_feed_token(token, url)
        expect(result).to be_nil, "Expected #{token.inspect} to be rejected"
      end
    end
  end

  describe 'URL Binding Security' do
    let(:username) { 'testuser' }
    let(:original_url) { 'https://example.com' }
    let(:valid_token) { described_class.generate_feed_token(username, original_url) }

    it 'rejects token when used with different URL' do
      different_urls = [
        'https://malicious.com',
        'https://example.com/path',
        'https://example.com?query=1',
        'http://example.com', # Different protocol
        'https://subdomain.example.com'
      ]

      different_urls.each do |url|
        result = described_class.validate_feed_token(valid_token, url)
        expect(result).to be_nil, "Expected token to be rejected for URL: #{url}"
      end
    end

    it 'accepts token when used with exact same URL', :aggregate_failures do
      result = described_class.validate_feed_token(valid_token, original_url)
      expect(result).not_to be_nil
      expect(result[:username]).to eq(username)
    end
  end

  describe 'Expiration Security' do
    let(:username) { 'testuser' }
    let(:url) { 'https://example.com' }

    it 'rejects expired tokens' do
      expired_token = described_class.generate_feed_token(username, url, expires_in: -3600) # 1 hour ago
      result = described_class.validate_feed_token(expired_token, url)
      expect(result).to be_nil
    end

    it 'accepts non-expired tokens' do
      valid_token = described_class.generate_feed_token(username, url, expires_in: 3600) # 1 hour from now
      result = described_class.validate_feed_token(valid_token, url)
      expect(result).not_to be_nil
    end

    it 'uses correct default expiration (10 years)', :aggregate_failures do
      token = described_class.generate_feed_token(username, url)
      token_data = JSON.parse(Base64.urlsafe_decode64(token), symbolize_names: true)

      expires_at = token_data[:payload][:expires_at]
      current_time = Time.now.to_i
      expected_expiry = current_time + 315_360_000 # 10 years

      expect(expires_at).to be > current_time
      expect(expires_at).to be_within(60).of(expected_expiry) # Within 1 minute
    end
  end

  describe 'Secret Key Security' do
    let(:username) { 'testuser' }
    let(:url) { 'https://example.com' }

    it 'fails token generation when secret key is missing' do
      allow(described_class).to receive(:secret_key).and_return(nil)

      token = described_class.generate_feed_token(username, url)
      expect(token).to be_nil
    end

    it 'fails token validation when secret key is missing' do
      valid_token = described_class.generate_feed_token(username, url)
      allow(described_class).to receive(:secret_key).and_return(nil)

      result = described_class.validate_feed_token(valid_token, url)
      expect(result).to be_nil
    end
  end

  describe 'User Permission Validation' do
    let(:admin_username) { 'admin' }
    let(:user_username) { 'testuser' }
    let(:allowed_url) { 'https://example.com' }
    let(:disallowed_url) { 'https://malicious.com' }

    it 'allows admin user to access any URL' do
      admin_token = described_class.generate_feed_token(admin_username, 'https://any-site.com')
      result = described_class.feed_url_allowed?(admin_token, 'https://any-site.com')
      expect(result).to be true
    end

    it 'restricts regular user to allowed URLs only', :aggregate_failures do
      user_token = described_class.generate_feed_token(user_username, allowed_url)

      # Should work for allowed URL
      result = described_class.feed_url_allowed?(user_token, allowed_url)
      expect(result).to be true

      # Should fail for disallowed URL
      result = described_class.feed_url_allowed?(user_token, disallowed_url)
      expect(result).to be false
    end
  end

  describe 'Token Structure Validation' do
    let(:username) { 'testuser' }
    let(:url) { 'https://example.com' }
    let(:token) { described_class.generate_feed_token(username, url) }

    it 'has correct token structure', :aggregate_failures do
      decoded = JSON.parse(Base64.urlsafe_decode64(token), symbolize_names: true)

      expect(decoded).to have_key(:payload)
      expect(decoded).to have_key(:signature)

      payload = decoded[:payload]
      expect(payload).to include(
        username: username,
        url: url
      )
      expect(payload).to have_key(:expires_at)
      expect(payload[:expires_at]).to be_a(Integer)
    end

    it 'has valid Base64 URL-safe encoding' do
      expect { Base64.urlsafe_decode64(token) }.not_to raise_error
    end

    it 'has valid JSON structure' do
      decoded = Base64.urlsafe_decode64(token)
      expect { JSON.parse(decoded) }.not_to raise_error
    end

    it 'has valid HMAC signature' do
      decoded = JSON.parse(Base64.urlsafe_decode64(token), symbolize_names: true)
      payload = decoded[:payload]
      signature = decoded[:signature]

      secret_key = described_class.secret_key
      expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret_key, payload.to_json)

      expect(signature).to eq(expected_signature)
    end
  end
end
