# frozen_string_literal: true

require 'spec_helper'

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

    describe '.create (input boundaries)' do
      def create(**overrides)
        described_class.create(
          username: 'alice', url: 'https://example.com/feed', secret_key: 'test-secret', **overrides
        )
      end

      it 'accepts usernames up to 100 characters of [A-Za-z0-9_-]', :aggregate_failures do
        expect(create(username: 'a' * 100)).not_to be_nil
        expect(create(username: "#{'a' * 99}!")).to be_nil
        expect(create(username: 'a' * 101)).to be_nil
        expect(create(username: 'Az09_-')).not_to be_nil
      end

      it 'rejects usernames with characters outside the allowed set or non-strings', :aggregate_failures do
        expect(create(username: "alice\nbob")).to be_nil
        expect(create(username: 'alice bob')).to be_nil
        expect(create(username: nil)).to be_nil
        expect(create(username: :alice)).to be_nil
      end

      it 'accepts strategies up to 50 characters of [a-z0-9_]', :aggregate_failures do
        expect(create(strategy: 'a' * 50)).not_to be_nil
        expect(create(strategy: 'a' * 51)).to be_nil
        expect(create(strategy: 'a0_')).not_to be_nil
        expect(create(strategy: 'A')).to be_nil
        expect(create(strategy: 'a-b')).to be_nil
        expect(create(strategy: "a\nb")).to be_nil
        expect(create(strategy: '')).to be_nil
        expect(create(strategy: :abc)).to be_nil
        expect(create(strategy: nil)).not_to be_nil
      end

      it 'rejects missing or empty secret keys', :aggregate_failures do
        expect(create(secret_key: '')).to be_nil
        expect(create(secret_key: nil)).to be_nil
        expect(create(secret_key: :secret)).to be_nil
      end

      it 'expires at now + expires_in (default DEFAULT_EXPIRY)', :aggregate_failures do
        now = Time.now.to_i
        allow(Time).to receive(:now).and_return(Time.at(now))

        expect(create.expires_at).to eq(now + Html2rss::Web::FeedToken::DEFAULT_EXPIRY)
        expect(create(expires_in: 60).expires_at).to eq(now + 60)
        expect(create(expires_in: '60').expires_at).to eq(now + 60)
      end

      it 'signs with HMAC-SHA256 over the JSON payload, including strategy only when present', :aggregate_failures do
        now = Time.now.to_i
        allow(Time).to receive(:now).and_return(Time.at(now))
        base = { username: 'alice', url: 'https://example.com/feed', expires_at: now + 10 }
        sign = ->(payload) { OpenSSL::HMAC.hexdigest('SHA256', 'test-secret', JSON.generate(payload)) }

        expect(create(expires_in: 10).signature).to eq(sign.call(base))
        expect(create(expires_in: 10, strategy: 'faraday').signature).to eq(sign.call(base.merge(strategy: 'faraday')))
      end

      it 'keeps the strategy in the signed payload so it cannot be swapped', :aggregate_failures do
        token = create(strategy: 'faraday')
        tampered = token.with(strategy: 'browserless')
        stripped = token.with(strategy: nil)

        expect(described_class.valid_signature?(token, 'test-secret')).to be(true)
        expect(described_class.valid_signature?(tampered, 'test-secret')).to be(false)
        expect(described_class.valid_signature?(stripped, 'test-secret')).to be(false)
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

      it 'rejects blank or non-string secrets', :aggregate_failures do
        token = described_class.create(username: 'alice', url: 'https://example.com/feed', secret_key: 'test-secret')

        expect(described_class.valid_signature?(token, '')).to be(false)
        expect(described_class.valid_signature?(token, nil)).to be(false)
        expect(described_class.valid_signature?(token, 123)).to be(false)
      end

      it 'rejects missing or differently sized signatures', :aggregate_failures do
        token = described_class.create(username: 'alice', url: 'https://example.com/feed', secret_key: 'test-secret')

        expect(described_class.valid_signature?(token.with(signature: nil), 'test-secret')).to be(false)
        expect(described_class.valid_signature?(token.with(signature: token.signature[0..-2]), 'test-secret'))
          .to be(false)
        expect(described_class.valid_signature?(token.with(signature: "#{token.signature}0"), 'test-secret'))
          .to be(false)
      end

      it 'rejects tokens forged with an empty secret' do
        forged = described_class.create(username: 'alice', url: 'https://example.com/feed', secret_key: 'x')
        payload = { username: 'alice', url: forged.url, expires_at: forged.expires_at }
        forged = forged.with(signature: OpenSSL::HMAC.hexdigest('SHA256', '', JSON.generate(payload)))

        expect(described_class.valid_signature?(forged, '')).to be(false)
      end

      it 'rejects same-length signatures that differ' do
        token = described_class.create(username: 'alice', url: 'https://example.com/feed', secret_key: 'test-secret')
        flipped = token.signature.sub(/.\z/) { |c| c == '0' ? '1' : '0' }

        expect(described_class.valid_signature?(token.with(signature: flipped), 'test-secret')).to be(false)
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

    describe '.decode (payload validation)' do
      def encode_document(document)
        Base64.urlsafe_encode64(Zlib::Deflate.deflate(document.to_json))
      end

      let(:payload) { { u: 'alice', l: 'https://example.com/feed', e: 123_456 } }

      it 'accepts payloads without a strategy and with a string strategy', :aggregate_failures do
        expect(described_class.decode(encode_document({ p: payload, s: 'sig' })))
          .to have_attributes(username: 'alice', url: 'https://example.com/feed', expires_at: 123_456,
                              signature: 'sig', strategy: nil)
        expect(described_class.decode(encode_document({ p: payload.merge(t: 'faraday'), s: 'sig' })).strategy)
          .to eq('faraday')
      end

      it 'rejects documents that are not objects', :aggregate_failures do
        expect(described_class.decode(encode_document([1, 2]))).to be_nil
        expect(described_class.decode(encode_document('str'))).to be_nil
      end

      it 'rejects missing, empty or non-string signatures', :aggregate_failures do
        expect(described_class.decode(encode_document({ p: payload }))).to be_nil
        expect(described_class.decode(encode_document({ p: payload, s: '' }))).to be_nil
        expect(described_class.decode(encode_document({ p: payload, s: 1 }))).to be_nil
      end

      it 'rejects non-object or incomplete payloads', :aggregate_failures do
        expect(described_class.decode(encode_document({ p: 'x', s: 'sig' }))).to be_nil
        expect(described_class.decode(encode_document({ p: payload.except(:u), s: 'sig' }))).to be_nil
        expect(described_class.decode(encode_document({ p: payload.except(:l), s: 'sig' }))).to be_nil
        expect(described_class.decode(encode_document({ p: payload.except(:e), s: 'sig' }))).to be_nil
        expect(described_class.decode(encode_document({ p: payload.merge(e: 1.5), s: 'sig' }))).to be_nil
      end

      it 'returns nil for corrupt zlib, base64 and JSON content', :aggregate_failures do
        expect(described_class.decode(Base64.urlsafe_encode64('not zlib'))).to be_nil
        expect(described_class.decode(Base64.urlsafe_encode64(Zlib::Deflate.deflate('{nope')))).to be_nil
        expect(described_class.decode(Base64.urlsafe_encode64(Zlib::Deflate.deflate('{"p":')[0..-3]))).to be_nil
        expect(described_class.decode('%%%')).to be_nil
      end
    end

    describe 'wire format compatibility' do
      it 'omits the strategy key when the token has none' do
        bare = token.with(strategy: nil)
        document = JSON.parse(Zlib::Inflate.inflate(Base64.urlsafe_decode64(described_class.encode(bare))))

        expect(document['p'].keys).to contain_exactly('u', 'l', 'e')
      end

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

  describe '#valid_for_url?' do
    it 'requires an exact url match', :aggregate_failures do
      token = described_class.new('alice', 'https://example.com/feed', 1, 'sig', nil)

      expect(token.valid_for_url?('https://example.com/feed')).to be(true)
      expect(token.valid_for_url?('https://example.com/feed/')).to be(false)
    end
  end

  describe '#expired?' do
    it 'is not expired at the exact expiry second' do
      now = Time.now.to_i
      allow(Time).to receive(:now).and_return(Time.at(now))

      expect(described_class.new('alice', 'https://example.com/feed', now, 'sig', nil).expired?).to be(false)
    end

    it 'returns true for past timestamps' do
      token = described_class.new('alice', 'https://example.com/feed', Time.now.to_i - 1, 'sig', nil)

      expect(token.expired?).to be(true)
    end

    it 'returns false for future timestamps' do
      token = described_class.new('alice', 'https://example.com/feed', Time.now.to_i + 3600, 'sig', nil)

      expect(token.expired?).to be(false)
    end
  end

  describe '.generate and .validate' do
    let(:context) do
      Html2rss::Web::RequestContext::Context.new(
        request_id: 'r', path: '/', http_method: 'GET', route_group: 'x', actor: nil, strategy: nil,
        started_at: Time.now, monotonic_start: 0
      )
    end

    before do
      Html2rss::Web::RequestContext.clear!
      allow(Html2rss::Web::RuntimeEnv).to receive(:secret_key).and_return('secret')
    end

    after { Html2rss::Web::RequestContext.clear! }

    it 'round-trips a generated token with its url and strategy', :aggregate_failures do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_token_usage)
      encoded = described_class.generate('alice', 'https://example.com/f', strategy: 'faraday')
      token = described_class.validate(encoded)

      expect(token).to have_attributes(username: 'alice', url: 'https://example.com/f', strategy: 'faraday')
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_token_usage).with(encoded, 'https://example.com/f',
                                                                                    true)
    end

    it 'honours expires_in', :aggregate_failures do
      encoded = described_class.generate('alice', 'https://example.com/f', expires_in: 60)
      decoded = described_class::Codec.decode(encoded)

      expect(decoded.expires_at).to be_within(2).of(Time.now.to_i + 60)
    end

    it 'defaults to the long-lived expiry' do
      decoded = described_class::Codec.decode(described_class.generate('alice', 'https://example.com/f'))

      expect(decoded.expires_at).to be_within(2).of(Time.now.to_i + Html2rss::Web::FeedToken::DEFAULT_EXPIRY)
    end

    it 'returns nil for invalid generation input' do
      expect(described_class.generate('', 'https://example.com/f')).to be_nil
    end

    it 'returns nil for undecodable tokens without logging usage' do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_token_usage)

      expect(described_class.validate('garbage')).to be_nil
      expect(Html2rss::Web::SecurityLogger).not_to have_received(:log_token_usage)
    end

    it 'rejects tokens signed with another secret and logs the failure', :aggregate_failures do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_token_usage)
      encoded = described_class.generate('alice', 'https://example.com/f')
      allow(Html2rss::Web::RuntimeEnv).to receive(:secret_key).and_return('other')

      expect(described_class.validate(encoded)).to be_nil
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_token_usage).with(encoded, 'https://example.com/f',
                                                                                    false)
    end

    it 'assigns the strategy to the request context only when present', :aggregate_failures do
      Html2rss::Web::RequestContext.set!(context)
      described_class.validate(described_class.generate('alice', 'https://example.com/f'))
      expect(Html2rss::Web::RequestContext.current.strategy).to be_nil

      described_class.validate(
        described_class.generate('alice', 'https://example.com/f', strategy: 'faraday')
      )
      expect(Html2rss::Web::RequestContext.current.strategy).to eq('faraday')
    end
  end
end
