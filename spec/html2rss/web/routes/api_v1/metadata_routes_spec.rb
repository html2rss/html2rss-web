# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Routes::ApiV1::MetadataRoutes, type: :request do
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app

  before do
    allow(Html2rss::Web::Api::V1::Strategies).to receive(:index).and_return({ success: true, data: { strategies: [] } })
    allow(Html2rss::Web::Api::V1::RootMetadata).to receive(:build).and_return({ api: { name: 'x' } })
  end

  describe 'openapi.yaml' do
    it 'permanently redirects GET to the public spec', :aggregate_failures do
      get '/api/v1/openapi.yaml'

      expect(last_response.status).to eq(301)
      expect(last_response.headers['Location']).to end_with('/openapi.yaml')
      expect(URI(last_response.headers['Location']).path).to eq('/openapi.yaml')
    end

    it 'does not answer non-GET requests with the redirect' do
      post '/api/v1/openapi.yaml'

      expect(last_response.status).not_to eq(301)
    end
  end

  describe 'strategies' do
    it 'renders the strategy index as JSON', :aggregate_failures do
      get '/api/v1/strategies'

      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq('success' => true, 'data' => { 'strategies' => [] })
      expect(Html2rss::Web::Api::V1::Strategies).to have_received(:index)
    end

    it 'does not serve non-GET requests' do
      post '/api/v1/strategies'

      expect(last_response.status).not_to eq(200)
    end
  end

  describe 'root' do
    it 'renders root metadata on /api/v1 and /api/v1/', :aggregate_failures do
      ['/api/v1', '/api/v1/'].each do |path|
        get path

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to include('success' => true, 'data' => { 'api' => { 'name' => 'x' } })
      end
    end

    it 'does not serve non-GET requests on the root' do
      post '/api/v1'

      expect(last_response.status).not_to eq(200)
    end
  end
end
