# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require_relative '../../app'

# rubocop:disable-next RSpec/MultipleExpectations
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
          <item>
            <description>Description-only label text that should not get an excerpt block when rendered.</description>
            <link>https://example.com/articles/4</link>
          </item>
        </channel>
      </rss>
    XML
  end

  it 'uses the feed icon in the hero and as the favicon' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.at_css('link[rel="icon"]')['href']).to eq('/feed.svg')
    expect(doc.at_css('.feed-hero__icon')['src']).to eq('/feed.svg')
    expect(doc.css('.feed-hero__icon-wrap')).to be_empty
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
    expect(copy_action['aria-live']).to eq('polite')
    expect(doc.at_css('[data-copy-feed-url-status]')).to be_nil
  end

  it 'uses ui-lede for the hero channel description' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.at_css('.feed-hero .ui-lede.layout-rail-copy')).not_to be_nil
    expect(doc.css('.feed-description')).to be_empty
  end

  it 'uses ui-headline-row with a right-aligned badge outside ui-actions' do
    doc = Nokogiri::HTML(rendered_html)
    headline_row = doc.at_css('.feed-hero .ui-headline-row')

    expect(headline_row).not_to be_nil
    expect(headline_row.at_css('.ui-display-title')).not_to be_nil
    expect(headline_row.at_css('.feed-hero__icon')['src']).to eq('/feed.svg')
    expect(doc.at_css('.feed-hero .ui-actions .feed-hero__icon')).to be_nil
    expect(doc.at_css('.feed-hero .ui-actions h1')).to be_nil
  end

  it 'places a context eyebrow before the headline row' do
    doc = Nokogiri::HTML(rendered_html)
    hero = doc.at_css('.feed-hero')
    eyebrow = hero.at_css('.ui-eyebrow')
    headline_row = hero.at_css('.ui-headline-row')

    expect(eyebrow.text.strip).to eq('RSS feed')
    expect(hero.element_children.index(eyebrow)).to be < hero.element_children.index(headline_row)
  end

  it 'uses the shared ui-actions row for hero controls' do
    doc = Nokogiri::HTML(rendered_html)
    actions = doc.css('.feed-hero .ui-actions').first

    expect(actions).not_to be_nil
    expect(actions.at_css('[data-feed-reader-link]')).not_to be_nil
    expect(actions.at_css('[data-copy-feed-url]')).not_to be_nil
    expect(actions.at_css('[data-json-feed-link]')).not_to be_nil
    expect(actions.element_children.none? { |node| %w[img h1].include?(node.name) }).to be(true)
  end

  it 'orders item meta before linked title to match the result preview' do
    doc = Nokogiri::HTML(rendered_html)
    first_item = doc.css('.ui-item').first
    item_children = first_item.element_children

    meta_index = item_children.index { |node| node['class']&.include?('ui-item__meta') }
    title_index = item_children.index { |node| node['class']&.include?('ui-item__title') }

    expect(meta_index).not_to be_nil
    expect(title_index).not_to be_nil
    expect(meta_index).to be < title_index
    expect(first_item.at_css('.ui-item__title > a')['href']).to eq('https://example.com/articles/1')
  end

  it 'renders minimal linked items without action rows' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.css('.ui-item__actions')).to be_empty
    expect(doc.css('.ui-item__title > a').length).to eq(4)
    expect(doc.at_css('.feed-section .ui-eyebrow').text.strip).to eq('4 items')
    expect(doc.css('.feed-meta .ui-eyebrow').map { |node| node.text.strip }).not_to include('Items')
    expect(doc.css('.ui-meta-row').length).to eq(2)
  end

  it 'suppresses excerpts for title-less items' do
    doc = Nokogiri::HTML(rendered_html)
    description_only_item = doc.css('.ui-item').last

    expect(description_only_item.at_css('.ui-item__excerpt')).to be_nil
    expect(description_only_item.at_css('.ui-item__title > a').text.strip).to include('Description-only label')
  end

  it 'does not render feed-only footer or signal markup' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.css('.feed-item__footer')).to be_empty
    expect(doc.css('.feed-item__signals')).to be_empty
    expect(doc.css('.feed-signal')).to be_empty
  end

  it 'places feed metadata after the item list, outside the hero' do
    doc = Nokogiri::HTML(rendered_html)
    feed_section = doc.at_css('.feed-section')
    feed_meta = doc.at_css('.feed-meta')

    expect(feed_meta).not_to be_nil
    expect(doc.at_css('.feed-hero .feed-meta')).to be_nil
    expect(feed_section).not_to be_nil
    expect(feed_section.xpath('following-sibling::*[1]').first).to eq(feed_meta)
  end

  it 'uses layout-section-divided for the item list and metadata sections' do
    doc = Nokogiri::HTML(rendered_html)

    expect(doc.at_css('.feed-section.layout-section-divided')).not_to be_nil
    expect(doc.at_css('.feed-meta.layout-section-divided')).not_to be_nil
  end

  it 'renders feed items in an uncarded ui-item-list' do
    doc = Nokogiri::HTML(rendered_html)
    item_list = doc.at_css('.ui-item-list')

    expect(item_list).not_to be_nil
    expect(item_list.name).to eq('ul')
    expect(doc.css('.ui-item-list > .ui-item').length).to eq(4)
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
    math_item = doc.css('.ui-item__title').find { |node| node.text.strip == 'Math 1 < 2 > 0' }

    expect(math_item).not_to be_nil
    expect(doc.css('.ui-item__excerpt')[1].text.strip).to eq('Math 1 < 2 > 0')
  end

  it 'surfaces last build time in a ui-eyebrow stamp with time element' do
    doc = Nokogiri::HTML(rendered_html)
    stamp = doc.css('.feed-hero .ui-eyebrow').find { |node| node.at_css('time') }

    expect(stamp).not_to be_nil
    expect(doc.css('.feed-hero__stamp')).to be_empty
    expect(stamp.text.gsub(/\s+/, ' ').strip).to eq('Updated Mon, 01 Jan 2024 00:00:00 GMT')
    expect(stamp.at_css('time').text.strip).to eq('Mon, 01 Jan 2024 00:00:00 GMT')
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

  context 'when channel metadata is minimal' do
    let(:feed_xml) do
      <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0">
          <channel>
            <title>Minimal Feed</title>
            <item>
              <title>Only item</title>
              <link>https://example.com/only</link>
            </item>
          </channel>
        </rss>
      XML
    end

    it 'omits the bottom metadata block when source and generator are absent' do
      doc = Nokogiri::HTML(rendered_html)

      expect(doc.at_css('.feed-meta')).to be_nil
    end
  end
end
