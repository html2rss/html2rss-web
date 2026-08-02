# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Renderer do
  let(:mock_feed) do
    instance_double(
      RSS::Rss,
      to_s: '<rss-serialized/>',
      channel: instance_double(RSS::Rss::Channel, title: 'Test Title', link: 'https://example.com',
                                                  description: 'Test Desc'),
      items: [
        instance_double(
          RSS::Rss::Channel::Item,
          guid: instance_double(RSS::Rss::Channel::Item::Guid, content: '1'),
          link: 'https://example.com/1',
          title: 'Item 1',
          description: 'Item Description',
          pubDate: Time.now.utc
        )
      ]
    )
  end

  let(:ok_payload) do
    Html2rss::Web::Feeds::Contracts::RenderPayload.new(
      feed: mock_feed,
      site_title: 'Test Title',
      url: 'https://example.com',
      strategy: 'faraday'
    )
  end

  let(:empty_payload) do
    Html2rss::Web::Feeds::Contracts::RenderPayload.new(
      feed: nil,
      site_title: 'Test Title',
      url: 'https://example.com',
      strategy: 'faraday'
    )
  end

  describe '.call' do
    context 'with ok status' do
      let(:result) do
        Html2rss::Web::Feeds::Contracts::RenderResult.new(
          status: :ok,
          payload: ok_payload,
          message: nil,
          ttl_seconds: 300,
          cache_key: 'key',
          error_message: nil,
          error_kind: nil
        )
      end

      it 'renders RSS XML directly' do
        expect(described_class.call(result, format: :rss)).to eq('<rss-serialized/>')
      end

      it 'renders JSON Feed format', :aggregate_failures do
        json = JSON.parse(described_class.call(result, format: :json_feed))
        expect(json['version']).to eq('https://jsonfeed.org/version/1.1')
        expect(json['title']).to eq('Test Title')
        expect(json['items'].first['id']).to eq('1')
      end
    end

    context 'with empty status' do
      let(:result) do
        Html2rss::Web::Feeds::Contracts::RenderResult.new(
          status: :empty,
          payload: empty_payload,
          message: nil,
          ttl_seconds: 300,
          cache_key: 'key',
          error_message: 'empty page',
          error_kind: :extraction_empty
        )
      end

      it 'renders empty warnings in RSS' do
        xml = described_class.call(result, format: :rss)
        expect(xml).to include('Content Extraction Issue')
        expect(xml).to include('Preview unavailable for this source')
      end

      it 'renders empty warnings in JSON Feed' do
        json = JSON.parse(described_class.call(result, format: :json_feed))
        expect(json['title']).to include('Content Extraction Issue')
        expect(json['items'].first['content_text']).to include('What you can do')
      end
    end
  end

  describe '.call_error' do
    before do
      config_double = instance_double(Html2rss::Config)
      allow(Html2rss).to receive(:configuration).and_return(config_double)
      allow(config_double).to receive(:stylesheets).and_return([{ href: '/custom.xsl', type: 'text/xsl' }])
    end

    it 'renders error in RSS and applies stylesheets', :aggregate_failures do
      xml = described_class.call_error(message: 'Invalid key', format: :rss)
      expect(xml).to include('Failed to generate feed: Invalid key')
      expect(xml).to include('<?xml-stylesheet href="/custom.xsl" type="text/xsl" media="all"?>')
    end

    it 'renders error in JSON Feed' do
      json = JSON.parse(described_class.call_error(message: 'Invalid key', format: :json_feed))
      expect(json['description']).to include('Failed to generate feed: Invalid key')
    end
  end
end
