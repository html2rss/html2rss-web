# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::Refine::Suggest do
  let(:account) { { username: 'alice', allowed_urls: ['*'] } }
  let(:url) { 'https://example.com/a' }
  let(:candidates) do
    { items: [{ selector: 'article', enhance: true, sample: 'Hi', roots: [:internal] }],
      title: [{ selector: 'h2', sample: 'Hi' }] }
  end
  let(:captured) do
    instance_double(Html2rss::Capture::CaptureResult, candidates:, segment_strategy: :dom,
                                                      admission_drops: { 'short' => 1 })
  end

  before do
    allow(Html2rss::Web::Api::V1::Refine::Access).to receive(:ensure_allowed!).and_return(account)
    allow(Html2rss).to receive(:capture).and_return(captured)
  end

  it 'runs live access checks for the account' do
    described_class.call(refine_request({ url: }))

    expect(Html2rss::Web::Api::V1::Refine::Access).to have_received(:ensure_allowed!)
      .with(instance_of(Rack::Request), live_fetch: true)
  end

  it 'sets the JSON content type' do
    request = refine_request({ url: })
    described_class.call(request)

    expect(request.response['Content-Type']).to eq('application/json')
  end

  it 'returns every bucket, trimming entries to the public keys', :aggregate_failures do
    data = described_class.call(refine_request({ url: }))[:data]

    expect(data[:candidates]).to eq(
      items: [{ selector: 'article', enhance: true, sample: 'Hi' }],
      title: [{ selector: 'h2', sample: 'Hi' }], link: [], published: []
    )
    expect(data).to include(segment_strategy: 'dom', admission_drops: { 'short' => 1 })
  end

  it 'is a successful response when the gem found nothing', :aggregate_failures do
    allow(captured).to receive_messages(candidates: {}, segment_strategy: nil)
    data = described_class.call(refine_request({ url: }))[:data]

    expect(data[:candidates]).to eq(items: [], title: [], link: [], published: [])
    expect(data[:segment_strategy]).to be_nil
  end

  it 'passes a trimmed items selector hint, or none', :aggregate_failures do
    described_class.call(refine_request({ url:, items_selector: ' article ' }))
    described_class.call(refine_request({ url:, items_selector: ' ' }))

    expect(Html2rss).to have_received(:capture).with(url, strategy: :auto, items_selector: 'article')
    expect(Html2rss).to have_received(:capture).with(url, strategy: :auto, items_selector: nil)
  end

  it 'accepts a hint of exactly the maximum length' do
    hint = 'a' * described_class::MAX_HINT_LENGTH

    expect { described_class.call(refine_request({ url:, items_selector: hint })) }.not_to raise_error
  end

  it 'rejects a longer hint before fetching', :aggregate_failures do
    hint = 'a' * (described_class::MAX_HINT_LENGTH + 1)

    expect { described_class.call(refine_request({ url:, items_selector: hint })) }
      .to raise_error(Html2rss::Web::BadRequestError, 'items_selector is too long')
    expect(Html2rss).not_to have_received(:capture)
  end

  it 'requires a URL' do
    expect { described_class.call(refine_request({})) }
      .to raise_error(Html2rss::Web::BadRequestError, 'URL parameter is required')
  end
end
