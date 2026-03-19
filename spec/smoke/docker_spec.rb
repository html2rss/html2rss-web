# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

RSpec.describe 'Dockerized API smoke test', :docker do
  let(:base_url) { ENV.fetch('SMOKE_BASE_URL', 'http://127.0.0.1:4000') }
  let(:health_token) { ENV.fetch('SMOKE_HEALTH_TOKEN', 'CHANGE_ME_HEALTH_CHECK_TOKEN') }
  let(:feed_token) { ENV.fetch('SMOKE_API_TOKEN', 'CHANGE_ME_ADMIN_TOKEN') }
  let(:auto_source_enabled) { ENV.fetch('SMOKE_AUTO_SOURCE_ENABLED', 'false') == 'true' }
  let(:feed_url) { 'https://www.ruby-lang.org/en/' }

  def get_json(path, headers: {})
    uri = URI.join(base_url, path)
    request = Net::HTTP::Get.new(uri, headers)
    perform_request(uri, request)
  end

  def get_response(path, headers: {})
    uri = URI.join(base_url, path)
    request = Net::HTTP::Get.new(uri, headers)
    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
    [response, response.body.to_s]
  end

  def post_json(path, body:, headers: {})
    uri = URI.join(base_url, path)
    request = Net::HTTP::Post.new(uri, headers.merge('Content-Type' => 'application/json'))
    request.body = JSON.generate(body)
    perform_request(uri, request)
  end

  def perform_request(uri, request)
    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
    [response, response.body.to_s.empty? ? {} : JSON.parse(response.body)]
  end

  def expect_created_feed_response(body)
    expect(body.fetch('success')).to be(true)
    expect(body.dig('data', 'feed', 'public_url')).to match(%r{^/api/v1/feeds/})
    expect(body.dig('data', 'feed', 'json_public_url')).to match(%r{^/api/v1/feeds/.+\.json$})
  end

  def expect_json_feed_response(path)
    feed_response, = get_response(path, headers: { 'Accept' => 'application/feed+json' })
    expect(feed_response['Content-Type']).to include('application/feed+json')
    expect(feed_response.code).not_to eq('401')
  end

  it 'exposes health endpoints without authentication requirements', :aggregate_failures do
    response, payload = get_json('/api/v1/health/ready')
    expect(response).to be_a(Net::HTTPOK)
    expect(payload.fetch('success')).to be(true)

    response, payload = get_json('/api/v1/health/live')
    expect(response).to be_a(Net::HTTPOK)
    expect(payload.fetch('success')).to be(true)
  end

  it 'requires authentication for the secure health endpoint', :aggregate_failures do
    response, payload = get_json('/api/v1/health')
    expect(response).to be_a(Net::HTTPUnauthorized)
    expect(payload.dig('error', 'code')).to eq('UNAUTHORIZED')

    response, payload = get_json('/api/v1/health', headers: { 'Authorization' => "Bearer #{health_token}" })
    expect(response).to be_a(Net::HTTPOK)
    expect(payload.dig('data', 'health', 'status')).to eq('healthy')
  end

  it 'creates a feed when provided with valid credentials', :aggregate_failures do
    payload = {
      url: feed_url,
      strategy: 'faraday'
    }

    response, body = post_json('/api/v1/feeds', body: payload)
    expect(response).to be_a(Net::HTTPUnauthorized)
    expect(body.dig('error', 'code')).to eq('UNAUTHORIZED')
  end

  it 'creates feed when auto source is enabled', :aggregate_failures do
    next unless auto_source_enabled

    payload = {
      url: feed_url,
      strategy: 'faraday'
    }

    response, body = post_json('/api/v1/feeds',
                               body: payload,
                               headers: { 'Authorization' => "Bearer #{feed_token}" })

    expect(response.code).to eq('201')
    expect_created_feed_response(body)
    expect_json_feed_response(body.dig('data', 'feed', 'json_public_url'))
  end

  it 'returns forbidden for authenticated creation when auto source is disabled', :aggregate_failures do
    next if auto_source_enabled

    payload = {
      url: feed_url,
      strategy: 'faraday'
    }

    response, body = post_json('/api/v1/feeds',
                               body: payload,
                               headers: { 'Authorization' => "Bearer #{feed_token}" })

    expect(response).to be_a(Net::HTTPForbidden)
    expect(body.dig('error', 'code')).to eq('FORBIDDEN')
    expect(body.dig('error', 'message')).to eq('Auto source feature is disabled')
  end
end
