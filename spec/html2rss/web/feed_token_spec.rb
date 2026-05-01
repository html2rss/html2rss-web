# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/web/security/feed_token'
require_relative '../../../app/web/security/url_validator'

RSpec.describe Html2rss::Web::FeedToken do
  describe '.create_with_validation' do
    it 'creates a valid feed token' do
      token = described_class.create_with_validation(
        username: 'alice',
        url: 'https://example.com/feed',
        secret_key: 'test-secret',
        strategy: 'some_strategy'
      )

      expect(token).to be_a(described_class)
      expect(token.username).to eq('alice')
    end

    it 'stores the normalized attributes' do
      token = described_class.create_with_validation(
        username: 'alice',
        url: 'https://example.com/feed',
        secret_key: 'test-secret',
        strategy: 'some_strategy'
      )

      expect(token.url).to eq('https://example.com/feed')
      expect(token.strategy).to eq('some_strategy')
    end

    it 'signs the token' do
      token = described_class.create_with_validation(
        username: 'alice',
        url: 'https://example.com/feed',
        secret_key: 'test-secret',
        strategy: 'some_strategy'
      )

      expect(token.signature).not_to be_nil
    end

    it 'returns nil for invalid username' do
      token = described_class.create_with_validation(
        username: '',
        url: 'https://example.com/feed',
        secret_key: 'test-secret'
      )

      expect(token).to be_nil
    end

    it 'returns nil for invalid url' do
      token = described_class.create_with_validation(
        username: 'alice',
        url: 'not-a-url',
        secret_key: 'test-secret'
      )

      expect(token).to be_nil
    end
  end

  describe '.validate_and_decode' do
    let(:secret_key) { 'test-secret' }
    let(:url) { 'https://example.com/feed' }
    let(:token) do
      described_class.create_with_validation(
        username: 'alice',
        url:,
        secret_key:,
        strategy: 'some_strategy'
      )
    end

    it 'returns the token when valid' do
      expect(described_class.validate_and_decode(token.encode, url, secret_key)).to eq(token)
    end

    it 'returns nil for wrong url' do
      expect(described_class.validate_and_decode(token.encode, 'https://different.com', secret_key)).to be_nil
    end

    it 'returns nil for wrong secret' do
      expect(described_class.validate_and_decode(token.encode, url, 'wrong-secret')).to be_nil
    end

    it 'returns nil for expired tokens' do
      expired = described_class.create_with_validation(username: 'alice', url:, secret_key:, expires_in: -10)

      expect(described_class.validate_and_decode(expired.encode, url, secret_key)).to be_nil
    end
  end

  describe '.decode' do
    let(:token) do
      described_class.create_with_validation(
        username: 'alice',
        url: 'https://example.com/feed',
        secret_key: 'test-secret',
        strategy: 'some_strategy'
      )
    end

    it 'decodes valid payloads' do
      expect(described_class.decode(token.encode)).to eq(token)
    end

    it 'rejects invalid strings' do
      expect(described_class.decode('invalid')).to be_nil
    end

    it 'rejects nil payloads' do
      expect(described_class.decode(nil)).to be_nil
    end
  end

  describe '#expired?' do
    it 'returns true for past timestamps' do
      token = described_class.new('alice', 'https://example.com/feed', Time.now.to_i - 1, 'sig', nil)

      expect(token.expired?).to be(true)
    end

    it 'returns false for future timestamps' do
      token = described_class.new('alice', 'https://example.com/feed', Time.now.to_i + 3600, 'sig', nil)

      expect(token.expired?).to be(false)
    end
  end

  describe '#valid_signature?' do
    it 'checks the signature against the payload' do
      token = described_class.create_with_validation(
        username: 'alice',
        url: 'https://example.com/feed',
        secret_key: 'test-secret'
      )

      expect(token.valid_signature?('test-secret')).to be(true)
      expect(token.valid_signature?('wrong-secret')).to be(false)
    end
  end
end
