# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'
require 'rack/mock'

RSpec.describe Html2rss::Web::Telemetry::Metrics do
  def scrape(token = nil)
    env = token ? { 'HTTP_AUTHORIZATION' => "Bearer #{token}" } : {}
    Rack::MockRequest.new(Html2rss::Web::App.freeze.app).get('/metrics', env)
  end

  it 'rejects a scrape without a real token' do
    ClimateControl.modify(HEALTH_CHECK_TOKEN: nil) do
      expect(scrape.status).to eq(401)
    end
  end

  it 'rejects the placeholder token' do
    ClimateControl.modify(HEALTH_CHECK_TOKEN: 'CHANGE_ME_HEALTH_CHECK_TOKEN') do
      expect(scrape('CHANGE_ME_HEALTH_CHECK_TOKEN').status).to eq(401)
    end
  end

  it 'returns the product series without request labels', :aggregate_failures do
    ClimateControl.modify(HEALTH_CHECK_TOKEN: 'metrics-token') do
      Html2rss::Web::Telemetry::Outcome.record(operation: 'feed.render', result: 'hit', reason: 'none')
      response = scrape('metrics-token')
      body = response.body

      expect(response.status).to eq(200)
      expect(response.content_type).to include('text/plain', 'version=0.0.4')
      expect(body).to include('html2rss_outcome_total', 'html2rss_up', 'html2rss_build_info')
      expect(body).not_to include('html2rss_outcome_total_total')
      expect(body).not_to match(/[{,](email|path|url|amount)=/)
    end
  end
end
