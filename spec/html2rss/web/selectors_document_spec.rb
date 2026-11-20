# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::SelectorsDocument do
  let(:selectors) { { items: { selector: 'article', enhance: true } } }

  def selectors_with_gsub(pattern)
    {
      items: { selector: 'article' },
      title: { selector: 'h2', post_process: [{ name: 'gsub', pattern:, replacement: ' ' }] }
    }
  end

  describe '.parse' do
    it 'symbolizes keys and leaves the caller hash untouched', :aggregate_failures do
      raw = { 'items' => { 'selector' => +'article', 'enhance' => false } }

      expect(described_class.parse(raw)).to eq(items: { selector: 'article', enhance: false })
      expect(raw.keys).to eq(['items'])
    end

    it 'treats nil and an empty object as no selectors', :aggregate_failures do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse({})).to be_nil
    end

    it 'rejects a non-object' do
      expect { described_class.parse('article') }
        .to raise_error(Html2rss::Web::BadRequestError, 'selectors must be an object')
    end

    it 'rejects selectors over the byte cap' do
      raw = { items: { selector: 'a' * (described_class::MAX_BYTES + 1) } }

      expect { described_class.parse(raw) }
        .to raise_error(Html2rss::Web::BadRequestError, "selectors exceed #{described_class::MAX_BYTES} bytes")
    end

    it 'accepts selectors of exactly the byte cap' do
      padding = described_class::MAX_BYTES - JSON.generate(items: { selector: '' }).bytesize
      raw = { items: { selector: 'a' * padding } }

      expect(described_class.parse(raw)).to eq(raw)
    end

    it 'raises SchemaInvalid carrying the gem report as message', :aggregate_failures do
      expect { described_class.parse(items: { selector: '' }) }.to raise_error(described_class::SchemaInvalid) { |error|
        expect(error.report).not_to be_success
        expect(error.message).to eq(error.report.to_s)
      }
    end

    it 'leaves gsub pattern bounds to the gem compile step', :aggregate_failures do
      expect(described_class.parse(selectors_with_gsub('\\s+')).dig(:title, :post_process, 0, :pattern)).to eq('\\s+')
      expect { described_class.parse(selectors_with_gsub('(a+)+$')) }
        .to raise_error(Html2rss::Web::BadRequestError, /pattern contains nested quantifiers/)
      expect { described_class.parse(selectors_with_gsub('a' * 300)) }
        .to raise_error(Html2rss::Web::BadRequestError, /pattern exceeds 256 characters/)
    end

    it 'accepts valid selectors' do
      expect(described_class.parse(selectors)).to eq(selectors)
    end
  end
end
