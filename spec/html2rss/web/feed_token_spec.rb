# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::FeedToken do
  describe Html2rss::Web::FeedToken::Signer do
    describe '.create' do
      it 'creates a valid feed token' do
        token = described_class.create(
          username: 'alice',
          url: 'https://example.com/feed',
          secret_key: 'test-secret',
          strategy: 'some_strategy'
        )

        expect(token).to be_a(Html2rss::Web::FeedToken)
        expect(token.username).to eq('alice')
      end

      it 'stores the normalized attributes' do
        token = described_class.create(
          username: 'alice',
          url: 'https://example.com/feed',
          secret_key: 'test-secret',
          strategy: 'some_strategy'
        )

        expect(token.url).to eq('https://example.com/feed')
        expect(token.strategy).to eq('some_strategy')
      end

      it 'signs the token' do
        token = described_class.create(
          username: 'alice',
          url: 'https://example.com/feed',
          secret_key: 'test-secret',
          strategy: 'some_strategy'
        )

        expect(token.signature).not_to be_nil
      end

      it 'returns nil for invalid username' do
        token = described_class.create(
          username: '',
          url: 'https://example.com/feed',
          secret_key: 'test-secret'
        )

        expect(token).to be_nil
      end

      it 'returns nil for invalid url' do
        token = described_class.create(
          username: 'alice',
          url: 'not-a-url',
          secret_key: 'test-secret'
        )

        expect(token).to be_nil
      end
    end

    describe '.validate' do
      let(:secret_key) { 'test-secret' }
      let(:url) { 'https://example.com/feed' }
      let(:token) do
        described_class.create(
          username: 'alice',
          url:,
          secret_key:,
          strategy: 'some_strategy'
        )
      end

      it 'returns the token when valid' do
        encoded = Html2rss::Web::FeedToken::Codec.encode(token)

        expect(described_class.validate(encoded, url, secret_key)).to eq(token)
      end

      it 'returns nil for wrong url' do
        encoded = Html2rss::Web::FeedToken::Codec.encode(token)

        expect(described_class.validate(encoded, 'https://different.com', secret_key)).to be_nil
      end

      it 'returns nil for wrong secret' do
        encoded = Html2rss::Web::FeedToken::Codec.encode(token)

        expect(described_class.validate(encoded, url, 'wrong-secret')).to be_nil
      end

      it 'returns nil for expired tokens' do
        expired = described_class.create(username: 'alice', url:, secret_key:, expires_in: -10)
        encoded = Html2rss::Web::FeedToken::Codec.encode(expired)

        expect(described_class.validate(encoded, url, secret_key)).to be_nil
      end
    end

    describe '.validate_decoded' do
      let(:secret_key) { 'test-secret' }
      let(:url) { 'https://example.com/feed' }
      let(:token) do
        described_class.create(
          username: 'alice',
          url:,
          secret_key:,
          strategy: 'some_strategy'
        )
      end

      it 'returns the token when signature, url, and expiry are valid' do
        expect(described_class.validate_decoded(token, url, secret_key)).to eq(token)
      end

      it 'returns nil for wrong url' do
        expect(described_class.validate_decoded(token, 'https://different.com', secret_key)).to be_nil
      end

      it 'returns nil for wrong secret' do
        expect(described_class.validate_decoded(token, url, 'wrong-secret')).to be_nil
      end

      it 'returns nil for expired tokens' do
        expired = described_class.create(username: 'alice', url:, secret_key:, expires_in: -10)

        expect(described_class.validate_decoded(expired, url, secret_key)).to be_nil
      end

      it 'returns nil when token is nil' do
        expect(described_class.validate_decoded(nil, url, secret_key)).to be_nil
      end
    end

    describe '.valid_signature?' do
      it 'checks the signature against the payload' do
        token = described_class.create(
          username: 'alice',
          url: 'https://example.com/feed',
          secret_key: 'test-secret'
        )

        expect(described_class.valid_signature?(token, 'test-secret')).to be(true)
        expect(described_class.valid_signature?(token, 'wrong-secret')).to be(false)
      end
    end
  end

  describe Html2rss::Web::FeedToken::Codec do
    let(:token) do
      Html2rss::Web::FeedToken::Signer.create(
        username: 'alice',
        url: 'https://example.com/feed',
        secret_key: 'test-secret',
        strategy: 'some_strategy'
      )
    end

    describe '.decode' do
      it 'decodes valid payloads' do
        expect(described_class.decode(described_class.encode(token))).to eq(token)
      end

      it 'rejects invalid strings' do
        expect(described_class.decode('invalid')).to be_nil
      end

      it 'rejects nil payloads' do
        expect(described_class.decode(nil)).to be_nil
      end

      it 'rejects payloads with incorrect types', :aggregate_failures do
        invalid_payloads = [
          { u: 'alice', l: 'https://example.com/feed', e: '123456' },
          { u: 123, l: 'https://example.com/feed', e: 123_456 },
          { u: 'alice', l: 123, e: 123_456 },
          { u: 'alice', l: 'https://example.com/feed', e: 123_456, t: 123 }
        ]

        invalid_payloads.each do |payload|
          bad_token = Base64.urlsafe_encode64(
            Zlib::Deflate.deflate({ p: payload, s: 'sig' }.to_json)
          )
          expect(described_class.decode(bad_token)).to be_nil
        end
      end
    end

    describe 'wire format compatibility' do
      it 'round-trips zlib+base64 JSON with p/s and u/l/e/t keys' do
        encoded = described_class.encode(token)
        inflated = Zlib::Inflate.inflate(Base64.urlsafe_decode64(encoded))
        document = JSON.parse(inflated, symbolize_names: true)

        expect(document.keys).to contain_exactly(:p, :s)
        expect(document).to include(
          p: a_hash_including(u: 'alice', l: 'https://example.com/feed', t: 'some_strategy', e: kind_of(Integer)),
          s: token.signature
        )
      end
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
end
