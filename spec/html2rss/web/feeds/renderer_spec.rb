# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Renderer do
  let(:mock_feed_result) do
    instance_double(
      Html2rss::FeedResult,
      to_rss: instance_double(RSS::Rss, to_s: '<rss-serialized/>')
    )
  end
  let(:ok_payload) do
    Html2rss::Web::Feeds::Contracts::RenderPayload.new(
      feed: mock_feed_result,
      site_title: 'Test Title',
      url: 'https://example.com'
    )
  end
  let(:empty_payload) do
    Html2rss::Web::Feeds::Contracts::RenderPayload.new(
      feed: nil,
      site_title: 'Test Title',
      url: 'https://example.com'
    )
  end

  before do
    allow(mock_feed_result).to receive(:to_json_feed).and_return(
      {
        version: 'https://jsonfeed.org/version/1.1',
        title: 'Test Title',
        home_page_url: 'https://example.com',
        description: 'Test Desc',
        items: [{ id: '1', url: 'https://example.com/1', title: 'Item 1', content_text: 'Item Description' }]
      }
    )
  end

  def rack_request(path:, accept: nil)
    env = Rack::MockRequest.env_for(path, 'HTTP_HOST' => 'example.test')
    env['HTTP_ACCEPT'] = accept if accept
    Rack::Request.new(env)
  end

  def ok_result
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: ok_payload,
      message: nil,
      ttl_seconds: 300,
      cache_key: 'key',
      error_message: nil,
      empty_reason: nil
    )
  end

  def empty_result
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :empty,
      payload: empty_payload,
      message: nil,
      ttl_seconds: 300,
      cache_key: 'key',
      error_message: 'empty page',
      empty_reason: 'content_extraction_empty'
    )
  end

  def render_body(result, path:, accept: nil)
    request = rack_request(path: path, accept: accept)
    response = Rack::Response.new
    described_class.render(result, response: response, request: request)
  end

  # rubocop:disable RSpec/ExampleLength
  describe '.render' do
    let(:request) { rack_request(path: '/api/v1/feeds/token.xml') }
    let(:response) { instance_double(Rack::Response, :[]= => nil, :status= => nil) }

    it 'renders RSS via FeedResult#to_rss for .xml paths' do
      expect(render_body(ok_result, path: '/api/v1/feeds/token.xml')).to eq('<rss-serialized/>')
    end

    it 'renders JSON Feed via FeedResult#to_json_feed for .json paths', :aggregate_failures do
      json = JSON.parse(render_body(ok_result, path: '/api/v1/feeds/token.json'))

      expect(json['version']).to eq('https://jsonfeed.org/version/1.1')
      expect(json['title']).to eq('Test Title')
      expect(json['items'].first['id']).to eq('1')
      expect(mock_feed_result).to have_received(:to_json_feed).with(
        feed_url: 'http://example.test/api/v1/feeds/token.json'
      )
    end

    it 'renders plain text warnings for empty results', :aggregate_failures do
      body = render_body(empty_result, path: '/api/v1/feeds/token.xml')

      expect(body).to include('Content Extraction Issue')
      expect(body).to include('What you can do')
    end

    it 'sets status, content-type, link alternates, vary, and cache control on the response', :aggregate_failures do
      allow(response).to receive(:status=)
      allow(response).to receive(:[]=)
      allow(Html2rss::Web::Feeds::HttpCache).to receive(:vary)
      allow(Html2rss::Web::Feeds::HttpCache).to receive(:expires)

      described_class.render(ok_result, response: response, request: request)

      expect(response).to have_received(:status=).with(200)
      expect(response).to have_received(:[]=).with('Content-Type', 'application/xml')
      expect(response).to have_received(:[]=).with(
        'Link',
        '</api/v1/feeds/token.xml>; rel="alternate"; type="application/rss+xml", ' \
        '</api/v1/feeds/token.json>; rel="alternate"; type="application/feed+json"'
      )
      expect(Html2rss::Web::Feeds::HttpCache).to have_received(:vary).with(response, 'Accept', 'Host')
      expect(Html2rss::Web::Feeds::HttpCache).to have_received(:expires).with(response, 300, cache_control: 'public')
    end

    it 'omits reverse-proxy Docker DNS Hosts from Link targets' do
      env = Rack::MockRequest.env_for('/api/v1/feeds/token.xml', 'HTTP_HOST' => 'html2rss-web-app-1:4000')
      proxied_response = Rack::Response.new

      described_class.render(ok_result, response: proxied_response, request: Rack::Request.new(env))

      expect(proxied_response['Link']).not_to include('html2rss-web-app-1')
    end

    it 'prefers json feed from Accept when path has no format suffix' do
      body = render_body(ok_result, path: '/api/v1/feeds/token', accept: 'application/feed+json;q=0.8, */*;q=0.2')

      expect(JSON.parse(body)['version']).to eq('https://jsonfeed.org/version/1.1')
    end

    it 'falls back to rss when json feed is refused by Accept' do
      body = render_body(
        ok_result,
        path: '/api/v1/feeds/token',
        accept: 'application/feed+json;q=0, application/xml;q=0.4'
      )

      expect(body).to eq('<rss-serialized/>')
    end

    it 'sets diagnostic headers when telemetry is available in feed status', :aggregate_failures do
      status_double = instance_double(
        Html2rss::Status,
        selected_strategy: :faraday,
        strategy_attempts: [
          { strategy: :faraday, items_count: 5, transport_meta: { 'render_ms' => 120, 'request_id' => 'req-abc' } }
        ]
      )
      allow(mock_feed_result).to receive(:status).and_return(status_double)
      resp = Rack::Response.new
      described_class.render(ok_result, response: resp, request: request)

      expect(resp['X-Html2rss-Strategy']).to eq('faraday')
      expect(resp['X-Html2rss-Render-Ms']).to eq('120')
      expect(resp['X-Html2rss-Request-Id']).to eq('req-abc')
    end

    it 'returns json feed when rss is refused by Accept' do
      body = render_body(
        ok_result,
        path: '/api/v1/feeds/token',
        accept: 'application/xml;q=0, application/feed+json;q=0.4'
      )

      expect(JSON.parse(body)['version']).to eq('https://jsonfeed.org/version/1.1')
    end
  end

  describe '.render_error' do
    let(:response) { instance_double(Rack::Response, :[]= => nil) }

    it 'sets plain text content-type and disables cache on the response', :aggregate_failures do
      allow(response).to receive(:[]=)
      allow(Html2rss::Web::Feeds::HttpCache).to receive(:expires_now)

      body = described_class.render_error('Test Error', response: response)

      expect(body).to eq('Failed to generate feed: Test Error')
      expect(response).to have_received(:[]=).with('Content-Type', 'text/plain; charset=utf-8')
      expect(Html2rss::Web::Feeds::HttpCache).to have_received(:expires_now).with(response)
    end
  end
  # rubocop:enable RSpec/ExampleLength
end
