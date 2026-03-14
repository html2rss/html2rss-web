# frozen_string_literal: true

require 'json'

module ApiContractHelpers
  def response_json(response)
    JSON.parse(response.body)
  end

  def expect_success_response(response)
    json = response_json(response)
    expect(json['success']).to be(true)
    yield json if block_given?
    json
  end

  def expect_error_response(response, code:)
    json = response_json(response)
    expect(json['success']).to be(false)
    expect(json.dig('error', 'code')).to eq(code)
    yield json if block_given?
    json
  end

  def expect_feed_payload(json)
    feed = json.fetch('data').fetch('feed')
    expect_feed_identifier_payload(feed)
    expect_feed_source_payload(feed)
    feed
  end

  def expect_feed_identifier_payload(feed)
    expect(feed.fetch('feed_token')).to be_a(String)
    expect(feed.fetch('public_url')).to match(%r{^/api/v1/feeds/})
    expect(feed.fetch('json_public_url')).to match(%r{^/api/v1/feeds/.+\.json$})
  end

  def expect_feed_source_payload(feed)
    expect(feed.fetch('url')).to be_a(String)
    expect(feed.fetch('strategy')).to be_a(String)
  end
end

RSpec.configure do |config|
  config.include ApiContractHelpers
end
