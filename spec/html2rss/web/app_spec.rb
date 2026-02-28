# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app'

RSpec.describe Html2rss::Web::App do
  it { expect(described_class).to be < Roda }

  context 'with Rack::Test' do
    include Rack::Test::Methods

    def app = described_class

    it 'serves the homepage with core security headers', :aggregate_failures do
      get '/'

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Security-Policy']).to include("default-src 'none'")
      expect(last_response.headers['Strict-Transport-Security']).to include('max-age=31536000')
    end

    it 'serves legacy feed routes with caching headers', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      allow(Html2rss::Web::Feeds).to receive(:generate_feed).and_return('<rss/>')
      allow(Html2rss::Web::LocalConfig).to receive(:find).and_return({ channel: { ttl: 180 } })

      get '/legacy'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      cache_control = last_response.headers['Cache-Control']
      expect(cache_control).to include('public')
      expect(cache_control).to include('max-age=10800')
      expect(last_response.body).to eq('<rss/>')
    end

    it 'coerces string ttl values before cache expiry math', :aggregate_failures do
      allow(Html2rss::Web::Feeds).to receive(:generate_feed).and_return('<rss/>')
      allow(Html2rss::Web::LocalConfig).to receive(:find).and_return({ channel: { ttl: '180' } })

      get '/legacy'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Cache-Control']).to include('max-age=10800')
    end

    it 'renders XML error when legacy feed generation fails', :aggregate_failures do
      allow(Html2rss::Web::XmlBuilder).to receive(:build_error_feed).and_return('<error/>')

      get '/missing-feed'

      expect(last_response.status).to eq(500)
      expect(last_response.headers['Content-Type']).to eq('application/xml')
      expect(last_response.body).to eq('<error/>')
    end

    it 'hides unexpected internal error details from API responses', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
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
