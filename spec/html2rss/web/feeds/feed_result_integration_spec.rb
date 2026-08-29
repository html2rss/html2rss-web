# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe 'FeedResult pipeline integration' do
  let(:page_url) { 'https://example.com/integration-feed' }
  let(:resolved_source) do
    Html2rss::Web::Feeds::Contracts::ResolvedSource.new(
      source_kind: :token,
      cache_identity: 'integration-feed:fixture',
      generator_input: generator_input,
      ttl_seconds: 600,
      url: page_url,
      strategy: :faraday,
      feed_name: nil,
      directory_defaults: {},
      request_params: {}
    )
  end
  let(:generator_input) do
    {
      channel: { url: page_url, title: 'Integration Feed' },
      strategy: :faraday,
      selectors: {
        items: { selector: 'article' },
        title: { selector: 'h1 a' },
        link: { selector: 'h1 a', extractor: 'href' }
      }
    }
  end
  let(:service_result) do
    Html2rss::Web::Feeds::Service.call(resolved_source)
  end

  around do |example|
    VCR.use_cassette('feed_result_integration') { example.run }
  end

  before do
    Html2rss::Web::Feeds::Cache.clear!(reason: 'spec')
    allow(Html2rss::Web::Feeds::ChannelTitle).to receive(:for)
      .with(page_url)
      .and_return('Integration Feed')
  end

  it 'runs Html2rss.feed_result through Service, Cache, and Renderer', :aggregate_failures do
    expect(service_result.status).to eq(:ok)
    expect_cached_feed_result
    expect_rss_render(service_result)
    expect_json_render(service_result)
  end

  # rubocop:disable RSpec/ExampleLength -- Link host-leak + feed_url Host vary asserted together
  it 'keeps relative Link targets while varying JSON feed_url by Host', :aggregate_failures do
    expect(service_result.status).to eq(:ok)

    other_host_response = Rack::Response.new
    other_host_request = feed_request(path: '/api/v1/feeds/integration-token.json', host: 'feeds.other.test')
    body = Html2rss::Web::Feeds::Renderer.render(
      service_result,
      response: other_host_response,
      request: other_host_request
    )
    json = JSON.parse(body)
    base_path = '/api/v1/feeds/integration-token'

    expect(other_host_response['Vary']).to include('Accept', 'Host')
    expect(other_host_response['Link']).to eq(expected_link_header(base_path: base_path))
    expect(other_host_response['Link']).not_to include('feeds.other.test')
    expect(json['feed_url']).to eq('http://feeds.other.test/api/v1/feeds/integration-token.json')
  end
  # rubocop:enable RSpec/ExampleLength

  # rubocop:disable RSpec/ExampleLength -- asserts empty status, channel title, plain body, and Vary together
  it 'prefers channel_title for empty scrape plain-text bodies', :aggregate_failures do
    empty_feed = instance_double(
      Html2rss::FeedResult,
      empty?: true,
      channel_title: 'Integration Feed Fixture'
    )
    allow(Html2rss).to receive(:feed_result).and_return(empty_feed)
    Html2rss::Web::Feeds::Cache.clear!(reason: 'spec')

    empty_result = Html2rss::Web::Feeds::Service.call(resolved_source)
    response = Rack::Response.new
    request = feed_request(path: '/api/v1/feeds/integration-token.xml', host: 'example.test')
    body = Html2rss::Web::Feeds::Renderer.render(empty_result, response: response, request: request)

    expect(empty_result.status).to eq(:empty)
    expect(empty_result.payload.site_title).to eq('Integration Feed Fixture')
    expect([response.status, response['Content-Type']]).to eq([422, 'text/plain; charset=utf-8'])
    expect(body).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY_MESSAGE)
    expect(response['Vary']).to eq('Accept')
  end
  # rubocop:enable RSpec/ExampleLength

  # @return [void]
  def expect_cached_feed_result # rubocop:disable Metrics/AbcSize
    second_result = Html2rss::Web::Feeds::Service.call(resolved_source)

    expect(service_result.payload.feed).to be_a(Html2rss::FeedResult)
    expect(service_result.payload.feed).not_to be_empty
    expect(second_result.payload.feed).to equal(service_result.payload.feed)
  end

  # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
  # @return [void]
  def expect_rss_render(result)
    response = Rack::Response.new
    request = feed_request(path: '/api/v1/feeds/integration-token.xml', host: 'example.test')
    body = Html2rss::Web::Feeds::Renderer.render(result, response: response, request: request)
    base_path = '/api/v1/feeds/integration-token'

    expect(
      [response.status, response['Content-Type'], response['Vary'], response['Link'], body.include?('Integration Item')]
    ).to eq(
      [200, 'application/xml', 'Accept, Host', expected_link_header(base_path: base_path), true]
    )
  end

  # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
  # @return [void]
  def expect_json_render(result)
    response = Rack::Response.new
    request = feed_request(path: '/api/v1/feeds/integration-token.json', host: 'example.test')
    body = Html2rss::Web::Feeds::Renderer.render(result, response: response, request: request)
    json = JSON.parse(body)

    expect(
      [response.status, response['Content-Type'], response['Vary'], json['feed_url'], json['items'].first['title']]
    ).to eq(
      [200, 'application/feed+json', 'Accept, Host',
       'http://example.test/api/v1/feeds/integration-token.json', 'Integration Item']
    )
  end

  # @param path [String]
  # @param host [String]
  # @return [Rack::Request]
  def feed_request(path:, host:)
    Rack::Request.new(Rack::MockRequest.env_for(path, 'HTTP_HOST' => host))
  end

  # @param base_path [String]
  # @return [String]
  def expected_link_header(base_path:)
    [
      "<#{base_path}.xml>; rel=\"alternate\"; type=\"application/rss+xml\"",
      "<#{base_path}.json>; rel=\"alternate\"; type=\"application/feed+json\""
    ].join(', ')
  end
end
