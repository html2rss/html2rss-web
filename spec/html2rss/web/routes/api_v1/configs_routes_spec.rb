# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Routes::ApiV1::ConfigsRoutes, type: :request do
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app

  let(:cors) do
    {
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Allow-Methods' => 'GET, OPTIONS',
      'Access-Control-Allow-Headers' => 'Accept, Content-Type'
    }
  end

  before do
    allow(Html2rss::Web::Flags).to receive(:config_catalog_enabled?).and_return(true)
    allow(Html2rss::Web::Api::V1::Configs).to receive(:index).and_return({ success: true, data: { configs: [] } })
  end

  it 'exposes the CORS contract constant', :aggregate_failures do
    expect(described_class::CORS_HEADERS).to eq(cors)
    expect(described_class::CORS_HEADERS).to be_frozen
  end

  it 'answers preflight with 204, an empty body and CORS headers', :aggregate_failures do
    options '/api/v1/configs'

    expect(last_response.status).to eq(204)
    expect(last_response.body).to eq('')
    expect(last_response.headers).to include(cors)
  end

  it 'serves the catalog with CORS headers', :aggregate_failures do
    get '/api/v1/configs'

    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq('success' => true, 'data' => { 'configs' => [] })
    expect(last_response.headers).to include(cors)
    expect(Html2rss::Web::Api::V1::Configs).to have_received(:index)
  end

  it 'returns 404 catalog_disabled when the flag is off, still with CORS', :aggregate_failures do
    allow(Html2rss::Web::Flags).to receive(:config_catalog_enabled?).and_return(false)
    get '/api/v1/configs'

    expect(last_response.status).to eq(404)
    expect(JSON.parse(last_response.body)).to eq('error' => 'catalog_disabled')
    expect(last_response.headers).to include(cors)
    expect(Html2rss::Web::Api::V1::Configs).not_to have_received(:index)
  end

  it 'does not serve other methods' do
    post '/api/v1/configs'

    expect(last_response.status).not_to eq(200)
  end
end
