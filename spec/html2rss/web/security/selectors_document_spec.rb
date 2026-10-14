# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::SelectorsDocument do # rubocop:disable RSpec/SpecFilePathFormat -- lives under security/ with feed token
  let(:selectors) { { items: { selector: 'article', enhance: true } } }
  let(:fragment) { { selectors: } }

  # @param pattern [String]
  # @return [Hash{Symbol=>Object}]
  def selectors_with_gsub(pattern)
    {
      items: { selector: 'article' },
      title: { selector: 'h2', post_process: [{ name: 'gsub', pattern:, replacement: ' ' }] }
    }
  end

  describe '.from_client and .from_wire' do
    it 'accepts a selectors document fragment and freezes the handoff', :aggregate_failures do
      document = described_class.from_client(fragment)

      expect(document.to_config_fragment).to eq(selectors:)
      expect(document.to_wire).to eq(document.to_config_fragment)
      expect(document).not_to be_empty
      expect { document.selectors[:items][:selector] << 'x' }.to raise_error(FrozenError)
      expect(described_class.from_wire(document.to_wire)).to eq(document)
    end

    it 'does not freeze the caller hash' do
      raw = { 'selectors' => { 'items' => { 'selector' => +'article', 'enhance' => true } } }

      described_class.from_client(raw)

      expect { raw['selectors']['items']['selector'] << 'x' }.not_to raise_error
    end

    it 'accepts string keys' do
      document = described_class.from_client(
        'selectors' => { 'items' => { 'selector' => 'article', 'enhance' => false } }
      )

      expect(document.selectors).to eq(items: { selector: 'article', enhance: false })
    end

    described_class::DENIED_ROOT_KEYS.each do |key|
      it "rejects #{key} on mint and on decode", :aggregate_failures do
        payload = fragment.merge(key => { 'url' => 'https://evil.example' })

        expect { described_class.from_client(payload) }
          .to raise_error(Html2rss::Web::BadRequestError, "#{key} is not allowed")
        expect { described_class.from_wire(payload) }
          .to raise_error(Html2rss::Web::BadRequestError, "#{key} is not allowed")
      end
    end

    it 'rejects unknown root keys' do
      expect { described_class.from_client(foo: 1) }
        .to raise_error(Html2rss::Web::BadRequestError, 'foo is not allowed')
    end

    it 'rejects a non-object fragment' do
      expect { described_class.from_wire('selectors') }
        .to raise_error(Html2rss::Web::BadRequestError, 'selectors document must be an object')
    end

    it 'rejects a non-object selectors value' do
      expect { described_class.from_client(selectors: 'article') }
        .to raise_error(Html2rss::Web::BadRequestError, 'selectors must be an object')
    end

    it 'rejects fragments over the wire byte cap' do
      payload = { selectors: { items: { selector: 'a' * (described_class::MAX_WIRE_BYTES + 1) } } }

      expect { described_class.from_client(payload) }.to raise_error(
        Html2rss::Web::BadRequestError,
        "selectors document exceeds #{described_class::MAX_WIRE_BYTES} bytes"
      )
    end

    it 'delegates shape failures to config validation' do
      expect { described_class.from_client(selectors: { items: { selector: '' } }) }
        .to raise_error(Html2rss::Web::BadRequestError, /selectors\.items\.selector \[invalid_value\]/)
    end
  end

  describe 'gsub post-processors' do
    it 'admits a gsub pattern and carries it into the signed wire', :aggregate_failures do
      document = described_class.from_client(selectors: selectors_with_gsub('\\s+'))
      encoded = Html2rss::Web::Auth.generate_feed_token('admin', 'https://example.com/feed', selectors: document)

      expect(document.to_wire.dig(:selectors, :title, :post_process, 0, :pattern)).to eq('\\s+')
      expect(Html2rss::Web::Auth.validate_and_decode_feed_token(encoded).selectors).to eq(document)
    end

    it 'leaves the pattern bounds to the gem compile step', :aggregate_failures do
      expect { described_class.from_client(selectors: selectors_with_gsub('(a+)+$')) }
        .to raise_error(Html2rss::Web::BadRequestError, /pattern contains nested quantifiers/)
      expect { described_class.from_client(selectors: selectors_with_gsub('a' * 300)) }
        .to raise_error(Html2rss::Web::BadRequestError, /pattern exceeds 256 characters/)
    end

    it 'still rejects a denied root key that travels with a post_process' do
      payload = { channel: { url: 'https://evil.example' }, selectors: selectors_with_gsub('x') }

      expect { described_class.from_client(payload) }
        .to raise_error(Html2rss::Web::BadRequestError, 'channel is not allowed')
    end
  end
end
