# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require_relative '../../app'

# rubocop:disable RSpec/MultipleExpectations
RSpec.describe 'public/rss.xsl' do
  subject(:rendered_html) do
    Nokogiri::XSLT(File.read(File.expand_path('../../public/rss.xsl', __dir__))).transform(Nokogiri::XML(feed_xml)).to_s
  end

  let(:feed_xml) do
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <rss version="2.0">
        <channel>
          <title>The Example Feed</title>
          <description>Example feed description with enough detail to exercise the hero copy.</description>
          <link>https://example.com/articles</link>
          <generator>html2rss V. 1.0.0</generator>
          <lastBuildDate>Mon, 01 Jan 2024 00:00:00 GMT</lastBuildDate>
          <item>
            <title>First article</title>
            <description><![CDATA[<p>First article excerpt.</p>]]></description>
            <link>https://example.com/articles/1</link>
            <pubDate>Mon, 01 Jan 2024 10:00:00 GMT</pubDate>
            <category>Policy</category>
            <author>editor@example.com</author>
            <enclosure url="https://example.com/articles/1.jpg" type="image/jpeg" />
          </item>
          <item>
            <title>Second article</title>
            <description><![CDATA[<p>Math 1 &lt; 2 &gt; 0</p>]]></description>
            <link>https://example.com/articles/2</link>
            <pubDate>Tue, 02 Jan 2024 10:00:00 GMT</pubDate>
          </item>
          <item>
            <title>Math 1 &lt; 2 &gt; 0</title>
            <description>Math 1 &lt; 2 &gt; 0</description>
            <link>https://example.com/articles/3</link>
            <pubDate>Wed, 03 Jan 2024 10:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML
  end

  it 'uses the feed icon in the hero and as the favicon' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.at_css('link[rel="icon"]')['href']).to eq('/feed.svg')
    expect(doc.at_css('.feed-hero__icon')['src']).to eq('/feed.svg')
  end

  it 'renders the feed-reader hero action with client-side wiring' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.at_css('[data-feed-reader-link]')).not_to be_nil
    expect(doc.at_css('[data-feed-reader-link]').text.strip).to eq('Open in feed reader')
    expect(doc.at_css('[data-feed-reader-link]')['href']).to eq('#')
    expect(doc.at_css('script')['src']).to eq('/feed-reader-link.js')
  end

  it 'uses the shared ui stylesheet' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.at_css('link[rel="stylesheet"]')['href']).to eq('/shared-ui.css')
  end

  it 'preserves plain-text angle brackets while stripping actual html tags' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.css('.feed-card__title').last.text.strip).to eq('Math 1 < 2 > 0')
    expect(doc.css('.feed-card__excerpt')[1].text.strip).to eq('Math 1 < 2 > 0')
  end

  it 'surfaces last build time in the hero instead of decorative quality pills' do
    doc = Nokogiri::HTML(rendered_html)
    hero_stamp = doc.at_css('.feed-hero__stamp')

    expect(hero_stamp.text.gsub(/\s+/, ' ').strip).to eq('Updated Mon, 01 Jan 2024 00:00:00 GMT')
    expect(doc.css('.feed-quality__pill')).to be_empty
  end

  it 'uses the shared brand lockup in the feed header' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.at_css('.brand-lockup')).not_to be_nil
    expect(doc.at_css('.brand-lockup__wordmark').text.strip).to eq('html2rss')
  end

  it 'shows muted quality indicators instead of item metadata values' do
    doc = Nokogiri::HTML(rendered_html)

    first_card_signals = doc.css('.feed-card').first.css('.feed-signal').map { |node| node.text.strip }

    expect(first_card_signals).to include('Summary', 'Image', 'Tags', 'Byline')
  end
end
# rubocop:enable RSpec/MultipleExpectations
