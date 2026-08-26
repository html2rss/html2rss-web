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
    expect(doc.at_css('script')['src']).to eq('/feed-page.js')
  end

  it 'renders the copy feed URL control with client-side wiring' do
    doc = Nokogiri::HTML(rendered_html)
    copy_action = doc.at_css('[data-copy-feed-url]')

    expect(copy_action).not_to be_nil
    expect(copy_action.text.strip).to eq('Copy feed URL')
    expect(copy_action.name).to eq('button')
    expect(copy_action['type']).to eq('button')
    expect(doc.at_css('[data-copy-feed-url-status]')).not_to be_nil
    expect(doc.at_css('[data-copy-feed-url-status]')['aria-live']).to eq('polite')
    expect(copy_action['aria-live']).to be_nil
  end

  it 'uses the shared ui-actions row for hero controls' do
    doc = Nokogiri::HTML(rendered_html)
    actions = doc.at_css('.ui-actions')

    expect(actions).not_to be_nil
    expect(actions.at_css('[data-feed-reader-link]')).not_to be_nil
    expect(actions.at_css('[data-copy-feed-url]')).not_to be_nil
    expect(actions.at_css('[data-json-feed-link]')).not_to be_nil
  end

  it 'renders feed items in an uncarded ui-item-list' do
    doc = Nokogiri::HTML(rendered_html)
    item_list = doc.at_css('.ui-item-list')

    expect(item_list).not_to be_nil
    expect(item_list.name).to eq('ul')
    expect(doc.css('.ui-item-list > .ui-item').length).to eq(3)
    expect(doc.css('.ui-item--card')).to be_empty
    doc.css('.ui-item-list > .ui-item').each do |item|
      expect(item['class']).not_to include('ui-card')
      expect(item.at_css('.ui-card')).to be_nil
    end
  end

  it 'renders the JSON feed hero action with client-side wiring' do
    doc = Nokogiri::HTML(rendered_html)
    json_action = doc.at_css('[data-json-feed-link]')

    expect(json_action).not_to be_nil
    expect(json_action.text.strip).to eq('Open JSON Feed')
    expect(json_action['href']).to eq('#')
    expect(json_action['target']).to eq('_blank')
    expect(json_action['rel']).to eq('noopener noreferrer')
  end

  it 'uses the shared ui and feed stylesheets without inline styles' do
    doc = Nokogiri::HTML(rendered_html)
    stylesheet_hrefs = doc.css('link[rel="stylesheet"]').map { |link| link['href'] }

    expect(stylesheet_hrefs).to eq(['/shared-ui.css', '/feed.css'])
    expect(doc.at_css('style')).to be_nil
  end

  it 'preserves plain-text angle brackets while stripping actual html tags' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.css('.ui-item__title').last.text.strip).to eq('Math 1 < 2 > 0')
    expect(doc.css('.ui-item__excerpt')[1].text.strip).to eq('Math 1 < 2 > 0')
  end

  it 'surfaces last build time in the hero instead of decorative quality pills' do
    doc = Nokogiri::HTML(rendered_html)
    hero_stamp = doc.at_css('.feed-hero__stamp')

    expect(hero_stamp.text.gsub(/\s+/, ' ').strip).to eq('Updated Mon, 01 Jan 2024 00:00:00 GMT')
    expect(doc.css('.feed-quality__pill')).to be_empty
  end

  it 'uses the shared brand lockup in the feed header' do
    doc = Nokogiri::HTML(rendered_html)
    lockup = doc.at_css('.brand-lockup')

    expect(lockup).not_to be_nil
    expect(lockup.name).to eq('a')
    expect(lockup['href']).to eq('/')
    expect(doc.at_css('.brand-lockup__wordmark').text.strip).to eq('html2rss')
  end

  it 'shows muted quality indicators instead of item metadata values' do
    doc = Nokogiri::HTML(rendered_html)

    first_item_signals = doc.css('.ui-item').first.css('.feed-signal').map { |node| node.text.strip }

    expect(first_item_signals).to include('Summary', 'Image', 'Tags', 'Byline')
  end
end
# rubocop:enable RSpec/MultipleExpectations
