# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app'

RSpec.describe Html2rss::Web::App do
  def json_feed_response_tuple
    [last_response.status, last_response.headers['Content-Type'], JSON.parse(last_response.body)]
  end

  def json_feed_error_tuple
    [
      last_response.status,
      last_response.headers['Content-Type'],
      JSON.parse(last_response.body).slice('version', 'title', 'description')
    ]
  end

  def static_feed_json
    '{"version":"https://jsonfeed.org/version/1.1"}'
  end

  def stub_static_feed(rss_body: '<rss/>', json_body: static_feed_json, ttl: 180)
    allow(Html2rss::Web::LocalConfig).to receive(:find).and_return({ channel: { ttl: ttl } })

    stub_static_renderers(static_feed_result(ttl:), rss_body:, json_body:)
  end

  def static_feed_result(ttl:)
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: nil,
      message: nil,
      ttl_seconds: Html2rss::Web::CacheTtl.seconds_from_minutes(ttl),
      cache_key: 'feed_result:spec',
      error_message: nil
    )
  end

  def stub_static_renderers(result, rss_body:, json_body:)
    allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
    allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).with(result).and_return(rss_body)
    allow(Html2rss::Web::Feeds::JsonRenderer).to receive(:call).with(result).and_return(json_body)
  end

  def static_service_error_result
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :error,
      payload: nil,
      message: 'Internal Server Error',
      ttl_seconds: 600,
      cache_key: 'feed_result:error',
      error_message: 'upstream timeout'
    )
  end

  def stub_static_service_error(feed_name)
    allow(Html2rss::Web::LocalConfig)
      .to receive(:find)
      .with(feed_name)
      .and_return({ channel: { ttl: 180 } })
    allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(static_service_error_result)
    allow(Html2rss::Web::XmlBuilder).to receive(:build_error_feed).and_return('<error/>')
  end

  def service_error_response_tuple(path)
    get path
    [
      last_response.status,
      last_response.headers['Content-Type'],
      last_response.headers['Cache-Control'].split(',').map(&:strip).sort,
      last_response.body
    ]
  end

  it { expect(described_class).to be < Roda }

  context 'with Rack::Test', :aggregate_failures do
    include Rack::Test::Methods

    def app = described_class

    it 'serves the homepage with core security headers' do
      get '/'

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Security-Policy']).to include("default-src 'none'")
      expect(last_response.headers['Strict-Transport-Security']).to include('max-age=31536000')
    end

    it 'serves static feed routes with caching headers' do
      stub_static_feed

      get '/legacy'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      cache_control = last_response.headers['Cache-Control']
      expect(cache_control).to include('public')
      expect(cache_control).to include('max-age=10800')
      expect(last_response.body).to eq('<rss/>')
    end

    it 'serves static json feed routes when json is requested by extension' do
      stub_static_feed
      get '/legacy.json'

      expect(json_feed_response_tuple).to eq(
        [200, 'application/feed+json', { 'version' => 'https://jsonfeed.org/version/1.1' }]
      )
    end

    it 'serves nested static feed routes' do
      allow(Html2rss::Web::LocalConfig).to receive(:find).with('team/releases').and_return({ channel: { ttl: 180 } })
      stub_static_renderers(static_feed_result(ttl: 180), rss_body: '<rss/>', json_body: static_feed_json)

      get '/team/releases.xml'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      expect(last_response.body).to eq('<rss/>')
    end

    it 'serves HEAD requests for static feed routes with negotiated headers only' do
      stub_static_feed
      head '/legacy'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      expect(last_response.headers['Cache-Control']).to include('max-age=10800')
      expect(last_response.body).to eq('')
    end

    it 'returns method not allowed for unsupported verbs on token feed routes' do
      post '/api/v1/feeds/test-token'

      expect(last_response.status).to eq(405)
      expect(last_response.headers['Allow']).to eq('GET')
    end

    it 'coerces string ttl values before cache expiry math' do
      stub_static_feed(ttl: '180')

      get '/legacy'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Cache-Control']).to include('max-age=10800')
    end

    it 'renders XML error when static feed generation fails' do
      allow(Html2rss::Web::XmlBuilder).to receive(:build_error_feed).and_return('<error/>')

      get '/missing-feed'

      expect(last_response.status).to eq(500)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      expect(last_response.body).to eq('<error/>')
    end

    it 'renders JSON Feed-shaped errors when static json feed generation fails' do
      get '/missing-feed.json'

      expect(json_feed_error_tuple).to eq(
        [500, 'application/feed+json', { 'version' => 'https://jsonfeed.org/version/1.1', 'title' => 'Error',
                                         'description' => 'Failed to generate feed: Internal Server Error' }]
      )
    end

    it 'renders service failures as non-cacheable xml feed errors' do
      stub_static_service_error('legacy-service-error')

      expect(service_error_response_tuple('/legacy-service-error')).to eq(
        [500, 'application/xml', %w[max-age=0 must-revalidate no-cache no-store private], '<error/>']
      )
    end

    it 'hides unexpected internal error details from API responses' do
      allow(Html2rss::Web::Routes::ApiV1).to receive(:call).and_raise(StandardError, 'boom')

      get '/api/v1'

      expect(last_response.status).to eq(500)
      expect(last_response.headers['Content-Type']).to include('application/json')
      json = JSON.parse(last_response.body)
      expect(json.dig('error', 'code')).to eq(Html2rss::Web::Api::V1::Contract::CODES[:internal_server_error])
      expect(json.dig('error', 'message')).to eq('Internal Server Error')
    end
  end

  describe '.development?' do
    subject { described_class.development? }

    around do |example|
      ClimateControl.modify(RACK_ENV: env) { example.run }
    end

    context 'when RACK_ENV is development' do
      let(:env) { 'development' }

      it { is_expected.to be true }
    end

    context 'when RACK_ENV is not development' do
      let(:env) { 'test' }

      it { is_expected.to be false }
    end
  end
end
