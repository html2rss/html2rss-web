# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'
require_relative '../../../../app/feed_token'

RSpec.describe 'api/v1' do # rubocop:disable RSpec/DescribeClass
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app

  before do
    allow(Html2rss::Web::AutoSource).to receive(:enabled?).and_return(true)
  end

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

  describe 'GET /api/v1/health' do
    let(:health_account) { { username: 'health-check', token: 'health-check-token-xyz789' } }

    before do
      allow(Html2rss::Web::HealthCheck).to receive(:find_health_check_account).and_return(health_account)
    end

    it 'requires bearer token', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil)

      get '/api/v1/health'

      expect(last_response.status).to eq(401)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('error' => include('code' => 'UNAUTHORIZED'))
    end

    it 'returns health status when token is valid', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(health_account)
      allow(Html2rss::Web::HealthCheck).to receive(:run).and_return('success')

      header 'Authorization', 'Bearer health-check-token-xyz789'
      get '/api/v1/health'

      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('data' => include('health' => include('status' => 'healthy')))

      header 'Authorization', nil
    end

    it 'returns error when health check fails', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(health_account)
      allow(Html2rss::Web::HealthCheck).to receive(:run).and_return('failing')

      header 'Authorization', 'Bearer health-check-token-xyz789'
      get '/api/v1/health'

      expect(last_response.status).to eq(500)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be false
      expect(response_data.dig('error', 'message')).to eq('Health check failed')
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
      expect(response_data['data']['feeds'].first).to have_key('public_url')
      expect(response_data['meta']).to have_key('total')
    end
  end

  describe 'GET /api/v1/feeds/:token' do
    it 'returns unauthorized when account not found', :aggregate_failures do
      token_double = double('FeedToken', url: 'https://example.com', username: 'ghost')
      allow(Html2rss::Web::FeedToken).to receive_messages(
        decode: token_double,
        validate_and_decode: token_double
      )
      allow(Html2rss::Web::Auth).to receive(:get_account_by_username).and_return(nil)

      get '/api/v1/feeds/token'

      expect(last_response.status).to eq(401)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be false
      expect(response_data.dig('error', 'code')).to eq('UNAUTHORIZED')
      expect(response_data.dig('error', 'message')).to eq('Account not found')
    end

    it 'returns bad request when strategy is unsupported', :aggregate_failures do
      token_double = double('FeedToken', url: 'https://example.com', username: 'tester')
      allow(Html2rss::Web::FeedToken).to receive_messages(
        decode: token_double,
        validate_and_decode: token_double
      )
      allow(Html2rss::Web::Auth).to receive_messages(get_account_by_username: { username: 'tester' },
                                                     url_allowed?: true)

      get '/api/v1/feeds/token', strategy: 'bad'

      expect(last_response.status).to eq(400)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be false
      expect(response_data.dig('error', 'message')).to eq('Unsupported strategy')
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
