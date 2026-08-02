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

  before do
    config_double = instance_double(Html2rss::Config)
    allow(Html2rss).to receive(:configuration).and_return(config_double)
    allow(config_double).to receive(:stylesheets).and_return([{ href: '/custom.xsl', type: 'text/xsl' }])
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

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '.render' do
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
    let(:response) { instance_double(Rack::Response, :[]= => nil, :status= => nil) }
    let(:request) { instance_double(Rack::Request) }

    before do
      allow(described_class).to receive(:request_path).with(request).and_return('/feed.xml')
      allow(described_class).to receive(:accept_header).with(request).and_return(nil)
    end

    it 'sets status, content-type, vary, and cache control on the response', :aggregate_failures do
      allow(response).to receive(:status=)
      allow(response).to receive(:[]=)
      allow(Html2rss::Web::HttpCache).to receive(:vary)
      allow(Html2rss::Web::HttpCache).to receive(:expires)

      described_class.render(result, response: response, request: request)

      expect(response).to have_received(:status=).with(200)
      expect(response).to have_received(:[]=).with('Content-Type', 'application/xml')
      expect(Html2rss::Web::HttpCache).to have_received(:vary).with(response, 'Accept')
      expect(Html2rss::Web::HttpCache).to have_received(:expires).with(response, 300, cache_control: 'public')
    end
  end

  describe '.render_error' do
    let(:response) { instance_double(Rack::Response, :[]= => nil) }
    let(:request) { instance_double(Rack::Request) }

    before do
      allow(described_class).to receive(:request_path).with(request).and_return('/feed.xml')
      allow(described_class).to receive(:accept_header).with(request).and_return(nil)
    end

    it 'sets content-type and disables cache on the response', :aggregate_failures do
      allow(response).to receive(:[]=)
      allow(Html2rss::Web::HttpCache).to receive(:expires_now)

      described_class.render_error('Test Error', response: response, request: request)

      expect(response).to have_received(:[]=).with('Content-Type', 'application/xml')
      expect(Html2rss::Web::HttpCache).to have_received(:expires_now).with(response)
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe '.from_path' do
    it 'resolves format from path suffix', :aggregate_failures do
      expect(described_class.from_path('/feed.json')).to eq(:json_feed)
      expect(described_class.from_path('/feed.rss')).to eq(:rss)
      expect(described_class.from_path('/feed.xml')).to eq(:rss)
      expect(described_class.from_path('/feed')).to be_nil
    end
  end

  describe '.strip_known_extension' do
    it 'removes known extensions', :aggregate_failures do
      expect(described_class.strip_known_extension('/feed.json')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed.rss')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed')).to eq('/feed')
    end
  end

  describe '.content_type' do
    it 'returns proper HTTP header string', :aggregate_failures do
      expect(described_class.content_type(:json_feed)).to eq('application/feed+json')
      expect(described_class.content_type(:rss)).to eq('application/xml')
    end
  end

  describe '.from_accept' do
    subject(:from_accept) { described_class.from_accept(accept_header) }

    context 'when wildcard media types are present' do
      let(:accept_header) { 'application/feed+json;q=0.8, */*;q=0.2' }

      it 'prefers the more specific json feed match' do
        expect(from_accept).to eq(:json_feed)
      end
    end

    context 'when json feed is explicitly refused' do
      let(:accept_header) { 'application/feed+json;q=0, application/xml;q=0.4' }

      it 'falls back to rss negotiation' do
        expect(from_accept).to be_nil
      end
    end

    context 'when rss is explicitly refused' do
      let(:accept_header) { 'application/xml;q=0, application/feed+json;q=0.4' }

      it 'returns json feed' do
        expect(from_accept).to eq(:json_feed)
      end
    end
  end
end
