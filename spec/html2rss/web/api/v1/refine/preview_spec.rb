# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::Refine::Preview do
  let(:account) { { username: 'alice', allowed_urls: ['*'] } }
  let(:url) { 'https://example.com/a' }
  let(:selectors) { { items: { selector: 'article' } } }
  let(:result) do
    instance_double(
      Html2rss::Test::Result, item_count: 2, sample_items: [{ title: 'A' }],
                              quality_report: instance_double(Html2rss::Test::QualityReport, to_h: { score: 1 }),
                              failure_kind: :empty_extraction,
                              validation_issues: [double(to_h: { code: 'x' })]
    )
  end

  before do
    allow(Html2rss::Web::Api::V1::Refine::Access).to receive(:ensure_allowed!).and_return(account)
    allow(Html2rss).to receive(:test).and_return(result)
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

  it 'symbolizes a string failure kind' do
    allow(result).to receive(:failure_kind).and_return('blocked')

    expect(described_class.call(refine_request({ url: }))[:data][:failure_kind]).to eq(:blocked)
  end

  it 'selects result fields without the RSS document', :aggregate_failures do
    data = described_class.call(refine_request({ url:, selectors: }))[:data]

    expect(data).to eq(
      item_count: 2, sample_items: [{ title: 'A' }], quality_report: { score: 1 },
      failure_kind: :empty_extraction, validation_issues: [{ code: 'x' }]
    )
  end

  it 'tolerates a result without report, kind or issues' do
    bare = instance_double(Html2rss::Test::Result, item_count: 0, sample_items: [], quality_report: nil,
                                                   failure_kind: nil, validation_issues: nil)
    allow(Html2rss).to receive(:test).and_return(bare)

    expect(described_class.call(refine_request({ url: }))[:data])
      .to eq(item_count: 0, sample_items: [], quality_report: nil, failure_kind: nil, validation_issues: nil)
  end

  it 'expands config through GeneratorInput with the signed-selectors shape', :aggregate_failures do
    described_class.call(refine_request({ url:, selectors: }))

    expect(Html2rss).to have_received(:test).with(hash_including(channel: { url: }, selectors:), min_items: 1)
  end

  it 'keeps auto_source when no selectors are sent' do
    described_class.call(refine_request({ url: }))

    expect(Html2rss).to have_received(:test).with(hash_including(auto_source: {}), min_items: 1)
  end

  it 'rejects schema-invalid selectors before fetching', :aggregate_failures do
    expect { described_class.call(refine_request({ url:, selectors: { items: { selector: '' } } })) }
      .to raise_error(Html2rss::Web::SelectorsDocument::SchemaInvalid)
    expect(Html2rss).not_to have_received(:test)
  end

  it 'requires a URL' do
    expect { described_class.call(refine_request({ selectors: })) }
      .to raise_error(Html2rss::Web::BadRequestError, 'URL parameter is required')
  end
end
