# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Routes::ApiV1::RefineRoutes do
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app

  describe 'HANDLERS' do
    it 'maps each path to its handler' do
      expect(described_class::HANDLERS).to eq(
        'validate' => Html2rss::Web::Api::V1::Refine::Validate,
        'preview' => Html2rss::Web::Api::V1::Refine::Preview,
        'suggest_selectors' => Html2rss::Web::Api::V1::Refine::Suggest
      )
    end
  end

  described_class::HANDLERS.each do |path, handler|
    it "serves POST /api/v1/refine/#{path} as JSON from #{handler.name.split('::').last}", :aggregate_failures do
      allow(handler).to receive(:call).and_return({ success: true, data: { routed: path } })

      post "/api/v1/refine/#{path}", '{}'

      expect(JSON.parse(last_response.body)).to eq('success' => true, 'data' => { 'routed' => path })
      expect(handler).to have_received(:call).with(satisfy { !it.nil? })
    end
  end

  it 'answers unknown paths with 404 and wrong verbs with 405', :aggregate_failures do
    post '/api/v1/refine/nope', '{}'
    expect(last_response.status).to eq(404)
    expect(JSON.parse(last_response.body).dig('error', 'code')).to eq(Html2rss::Web::NotFoundError::CODE)

    get '/api/v1/refine/validate'
    expect(last_response.status).to eq(405)
  end
end
