# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::App do
  include Rack::Test::Methods

  def app = described_class

  describe 'GET /api/v1' do
    it 'returns API information', :aggregate_failures do
      get '/api/v1'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['data']['api']['version']).to eq('1.0.0')
      expect(response_data['data']['api']['name']).to eq('html2rss-web API')
    end
  end

  describe 'GET /api/v1/docs' do
    it 'returns OpenAPI documentation', :aggregate_failures do
      get '/api/v1/docs'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/yaml')
      expect(last_response.body).to include('openapi: 3.1.0')
    end
  end

  describe 'GET /api/v1/feeds' do
    it 'returns feeds list', :aggregate_failures do
      get '/api/v1/feeds'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['data']).to have_key('feeds')
      expect(response_data['meta']).to have_key('total')
    end
  end

  describe 'GET /api/v1/strategies' do
    it 'returns strategies list', :aggregate_failures do
      get '/api/v1/strategies'

      if last_response.status != 200
        puts "Response body: #{last_response.body}"
        puts "Response status: #{last_response.status}"
      end

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['data']).to have_key('strategies')
      expect(response_data['meta']).to have_key('total')
    end
  end

  describe 'GET /api/v1/strategies/{id}' do
    it 'returns strategy details', :aggregate_failures do
      get '/api/v1/strategies/ssrf_filter'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['data']).to have_key('strategy')

      # Check the strategy details
      strategy = response_data['data']['strategy']
      expect(strategy).not_to be_nil
      expect(strategy['id']).to eq('ssrf_filter')
    end

    it 'returns 404 for unknown strategy', :aggregate_failures do
      get '/api/v1/strategies/nonexistent_strategy'

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be false
      expect(response_data['error']['code']).to eq('NOT_FOUND')
      expect(response_data['error']['message']).to eq('Strategy not found')
    end
  end

  describe 'GET /api/v1/feeds/{id}' do
    context 'with XML Accept header' do
      it 'returns RSS content', :aggregate_failures do
        VCR.use_cassette('example_feed') do
          header 'Accept', 'application/xml'
          get '/api/v1/feeds/example'

          expect(last_response.status).to eq(200)
          expect(last_response.content_type).to include('application/xml')
          expect(last_response.body).to include('<rss')
        end
      end
    end
  end

  describe 'POST /api/v1/feeds' do
    context 'without authentication' do
      it 'returns 401 unauthorized', :aggregate_failures do
        post '/api/v1/feeds', { url: 'https://example.com' }.to_json,
             'CONTENT_TYPE' => 'application/json'

        expect(last_response.status).to eq(401)
        expect(last_response.content_type).to include('application/json')

        response_data = JSON.parse(last_response.body)
        expect(response_data['success']).to be false
        expect(response_data['error']['code']).to eq('UNAUTHORIZED')
      end
    end
  end

  describe 'GET /api/v1/health/ready' do
    it 'returns readiness status', :aggregate_failures do
      get '/api/v1/health/ready'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['data']['readiness']['status']).to eq('ready')
    end
  end

  describe 'GET /api/v1/health/live' do
    it 'returns liveness status', :aggregate_failures do
      get '/api/v1/health/live'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['data']['liveness']['status']).to eq('alive')
    end
  end
end
