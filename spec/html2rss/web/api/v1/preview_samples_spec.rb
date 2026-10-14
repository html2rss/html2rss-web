# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::PreviewSamples do
  def preview_result(rss:, sample_items: [])
    Struct.new(:rss, :sample_items).new(rss, sample_items)
  end

  def rss_item(index, extra = '')
    %(<item><title>Item #{index}</title><link>https://example.com/#{index}</link>#{extra}</item>)
  end

  def rss_document(items)
    %(<rss version="2.0"><channel><title>t</title>#{items}</channel></rss>)
  end

  def image_rss
    items = [
      rss_item(1, '<description>&lt;img src="https://cdn.example/1.jpg"&gt;</description>'),
      rss_item(2, '<description>&lt;img src="javascript:alert(1)"&gt;</description>'),
      rss_item(3, '<enclosure url="data:image/png;base64,aaaa" type="image/png" length="1"/>'),
      rss_item(4, '<enclosure url="http://cdn.example/4.jpg" type="image/jpeg" length="2"/>')
    ]
    rss_document(items.join)
  end

  it 'maps rss rows and keeps only safe http images', :aggregate_failures do
    rows = described_class.from_result(preview_result(rss: image_rss))

    expect(rows.map { it['image'] }).to eq(
      ['https://cdn.example/1.jpg', nil, nil, 'http://cdn.example/4.jpg']
    )
    expect(rows[1]).not_to have_key('image')
    expect(rows[0].keys - described_class::SAMPLE_KEYS).to be_empty
  end

  it 'caps mapped rows at the sample limit', :aggregate_failures do
    items = (1..12).map { rss_item(it) }.join
    rows = described_class.from_result(preview_result(rss: rss_document(items)))

    expect(rows.length).to eq(described_class::SAMPLE_LIMIT)
    expect(rows.last['title']).to eq('Item 10')
  end

  it 'keeps gem samples when the rss document cannot be parsed', :aggregate_failures do
    gem_samples = [{ 'title' => 'A' }]

    expect(described_class.from_result(preview_result(rss: '<not rss', sample_items: gem_samples))).to eq(gem_samples)
    expect(described_class.from_result(preview_result(rss: nil, sample_items: gem_samples))).to eq(gem_samples)
  end
end
