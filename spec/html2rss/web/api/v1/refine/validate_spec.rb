# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::Refine::Validate do
  let(:account) { { username: 'alice', allowed_urls: ['*'] } }
  let(:selectors) { { items: { selector: 'article' }, title: { selector: 'h2' } } }

  before { allow(Html2rss::Web::Api::V1::Refine::Access).to receive(:ensure_allowed!).and_return(account) }

  describe '.call' do
    it 'returns the report, normalized selectors and YAML with the page URL', :aggregate_failures do
      request = refine_request({ url: 'https://example.com/a', selectors: })
      data = described_class.call(request)[:data]

      expect(data[:report][:success]).to be(true)
      expect(data[:selectors]).to eq(selectors)
      expect(YAML.safe_load(data[:yaml])).to eq(
        'channel' => { 'url' => 'https://example.com/a' },
        'selectors' => JSON.parse(selectors.to_json)
      )
    end

    it 'exports YAML without a channel when no URL was sent', :aggregate_failures do
      data = described_class.call(refine_request({ selectors: }))[:data]

      expect(YAML.safe_load(data[:yaml]).keys).to eq(['selectors'])
      expect(data[:report][:success]).to be(true)
    end

    it 'reports a schema failure without selectors or YAML', :aggregate_failures do
      data = described_class.call(refine_request({ selectors: { items: { selector: '' } } }))[:data]

      expect(data).to include(selectors: nil, yaml: nil)
      expect(data[:report][:success]).to be(false)
    end

    it 'returns the gem report for empty selectors without exporting YAML', :aggregate_failures do
      data = described_class.call(refine_request({ selectors: {} }))[:data]

      expect(data).to include(selectors: nil, yaml: nil)
      expect(data[:report]).to include(success: true)
    end

    it 'validates against the caller page URL, or a placeholder', :aggregate_failures do
      allow(Html2rss::Config).to receive(:validate).and_call_original

      described_class.call(refine_request({ url: 'https://example.com/a', selectors: }))
      described_class.call(refine_request({ selectors: }))

      expect(Html2rss::Config).to have_received(:validate)
        .with(hash_including(channel: { url: 'https://example.com/a' })).at_least(:once)
      expect(Html2rss::Config).to have_received(:validate)
        .with(hash_including(channel: { url: 'https://example.com/' })).at_least(:once)
    end

    it 'authorizes the request without a live fetch' do
      request = refine_request({ selectors: })
      described_class.call(request)

      expect(Html2rss::Web::Api::V1::Refine::Access).to have_received(:ensure_allowed!).with(request)
    end

    it 'sets the JSON content type' do
      request = refine_request({ selectors: })
      described_class.call(request)

      expect(request.response['Content-Type']).to eq('application/json')
    end

    it 'requires selectors' do
      expect { described_class.call(refine_request({})) }
        .to raise_error(Html2rss::Web::BadRequestError, 'selectors is required')
    end

    it 'keeps a non-object selectors value a 400' do
      expect { described_class.call(refine_request({ selectors: 'x' })) }
        .to raise_error(Html2rss::Web::BadRequestError, 'selectors must be an object')
    end
  end
end
