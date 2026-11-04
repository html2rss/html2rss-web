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
                              rss: nil,
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

  it 'fetches the page inside the refine page cache scope' do
    allow(Html2rss::Web::Api::V1::Refine::PageCache).to receive(:within).and_call_original
    described_class.call(refine_request({ url: }))

    expect(Html2rss::Web::Api::V1::Refine::PageCache).to have_received(:within)
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

  it 'fetches with the strategy the person pinned', :aggregate_failures do
    described_class.call(refine_request({ url:, selectors:, strategy: 'botasaurus' }))

    expect(Html2rss).to have_received(:test) do |config, **|
      expect(config[:strategy]).to eq(:botasaurus)
    end
  end

  it 'rejects an unknown strategy' do
    expect { described_class.call(refine_request({ url:, selectors:, strategy: 'nope' })) }
      .to raise_error(Html2rss::Web::BadRequestError)
  end

  it 'lists items from the generated RSS beyond the gem samples', :aggregate_failures do
    entries = Array.new(120) do |index|
      "<item><title> Post #{index} </title><link>https://example.com/#{index}</link>" \
        '<pubDate>Fri, 05 Jan 2024 10:00:00 +0000</pubDate></item>'
    end
    allow(result).to receive(:rss).and_return("<rss><channel>#{entries.join}</channel></rss>")
    items = described_class.call(refine_request({ url:, selectors: }))[:data][:sample_items]

    expect(items.size).to eq(described_class::SAMPLE_LIMIT)
    expect(items.first).to eq(title: 'Post 0', url: 'https://example.com/0', published_at: '2024-01-05T10:00:00+00:00')
  end

  it 'leaves published_at empty when the feed date is missing or invalid', :aggregate_failures do
    allow(result).to receive(:rss).and_return(
      '<rss><channel><item><title>A</title><link>u</link><pubDate>soon</pubDate></item>' \
      '<item><title>B</title></item></channel></rss>'
    )
    items = described_class.call(refine_request({ url:, selectors: }))[:data][:sample_items]

    expect(items.map { |item| item[:published_at] }).to eq([nil, nil])
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
                                                   rss: nil, failure_kind: nil, validation_issues: nil)
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
