# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/xml_builder'
require_relative '../../../app/auth'

RSpec.describe Html2rss::Web::XmlBuilder do
  describe '.build_rss_feed' do
    it 'escapes XML special characters in title', :aggregate_failures do
      result = described_class.build_rss_feed(
        title: 'Test & "Special" <Characters>',
        description: 'A test feed',
        items: []
      )

      expect(result).to include('Test &amp; "Special" &lt;Characters&gt;')
      expect(result).not_to include('Test & "Special" <Characters>')
      expect(result).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
      expect(result).to include('<rss version="2.0">')
    end

    it 'escapes XML special characters in description', :aggregate_failures do
      result = described_class.build_rss_feed(
        title: 'Test Feed',
        description: 'Description with & "quotes" and <tags>',
        items: []
      )

      expect(result).to include('Description with &amp; "quotes" and &lt;tags&gt;')
      expect(result).not_to include('Description with & "quotes" and <tags>')
    end

    it 'escapes XML special characters in item content', :aggregate_failures do
      result = described_class.build_rss_feed(
        title: 'Test Feed',
        description: 'A test feed',
        items: [
          {
            title: 'Item with & "quotes" and <tags>',
            description: 'Description with & "quotes" and <tags>',
            link: 'https://example.com?param=value&other=<script>'
          }
        ]
      )

      expect(result).to include('Item with &amp; "quotes" and &lt;tags&gt;')
      expect(result).to include('Description with &amp; "quotes" and &lt;tags&gt;')
      expect(result).to include('https://example.com?param=value&amp;other=&lt;script&gt;')
    end

    it 'handles nil values gracefully', :aggregate_failures do
      result = described_class.build_rss_feed(
        title: nil,
        description: nil,
        items: [
          {
            title: nil,
            description: nil,
            link: nil
          }
        ]
      )

      expect(result).to include('<title/>')
      expect(result).to include('<description/>')
    end

    it 'generates valid RSS 2.0 XML', :aggregate_failures do
      result = described_class.build_rss_feed(
        title: 'Test Feed',
        description: 'A test feed',
        link: 'https://example.com',
        items: [
          {
            title: 'Test Item',
            description: 'A test item',
            link: 'https://example.com/item',
            pubDate: 'Mon, 01 Jan 2024 12:00:00 GMT'
          }
        ]
      )

      expect(result).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
      expect(result).to include('<rss version="2.0">')
      expect(result).to include('<channel>')
      expect(result).to include('<title>Test Feed</title>')
      expect(result).to include('<description>A test feed</description>')
      expect(result).to include('<link>https://example.com</link>')
      expect(result).to include('<item>')
      expect(result).to include('<title>Test Item</title>')
      expect(result).to include('<description>A test item</description>')
      expect(result).to include('<link>https://example.com/item</link>')
      expect(result).to include('<pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>')
    end
  end

  describe '.build_error_feed' do
    it 'creates error feed with escaped message', :aggregate_failures do
      result = described_class.build_error_feed(message: 'Error with & "quotes" and <tags>')

      expect(result).to include('Error with &amp; "quotes" and &lt;tags&gt;')
      expect(result).to include('<title>Error</title>')
      expect(result).to include('Failed to generate feed:')
    end

    it 'allows custom title', :aggregate_failures do
      result = described_class.build_error_feed(
        message: 'Custom error',
        title: 'Custom Error Title'
      )

      expect(result).to include('<title>Custom Error Title</title>')
    end
  end

  describe '.build_access_denied_feed' do
    it 'creates access denied feed with escaped URL', :aggregate_failures do
      result = described_class.build_access_denied_feed('https://example.com?param=value&other=<script>')

      expect(result).to include('https://example.com?param=value&amp;other=&lt;script&gt;')
      expect(result).to include('<title>Access Denied</title>')
      expect(result).to include('not in the allowed list')
    end
  end

  describe '.build_empty_feed_warning' do
    it 'creates empty feed warning with site title', :aggregate_failures do
      result = described_class.build_empty_feed_warning(
        url: 'https://example.com',
        strategy: 'ssrf_filter',
        site_title: 'Example Site'
      )

      expect(result).to include('<title>Example Site - Content Extraction Issue</title>')
      expect(result).to include('<link>https://example.com</link>')
      expect(result).to include('Content Extraction Failed')
    end

    it 'creates empty feed warning without site title', :aggregate_failures do
      result = described_class.build_empty_feed_warning(
        url: 'https://example.com',
        strategy: 'ssrf_filter',
        site_title: nil
      )

      expect(result).to include('<title>Content Extraction Issue</title>')
      expect(result).not_to include(' - Content Extraction Issue')
    end

    it 'escapes special characters in URL and strategy', :aggregate_failures do
      result = described_class.build_empty_feed_warning(
        url: 'https://example.com?param=value&other=<script>',
        strategy: 'strategy_with_&_and_<tags>',
        site_title: nil
      )

      expect(result).to include('https://example.com?param=value&amp;other=&lt;script&gt;')
      expect(result).to include('strategy_with_&amp;_and_&lt;tags&gt;')
    end
  end

  describe 'XML injection prevention' do
    it 'prevents XML injection in all fields', :aggregate_failures do
      malicious_input = '"><script>alert("xss")</script><title>'

      result = described_class.build_rss_feed(
        title: malicious_input,
        description: malicious_input,
        link: malicious_input,
        items: [
          {
            title: malicious_input,
            description: malicious_input,
            link: malicious_input
          }
        ]
      )

      # Should not contain unescaped script tags
      expect(result).not_to include('<script>')

      # Should contain properly escaped content
      expect(result).to include('&lt;script&gt;alert("xss")&lt;/script&gt;')
      expect(result).to include('&gt;&lt;title&gt;')
    end
  end
end
