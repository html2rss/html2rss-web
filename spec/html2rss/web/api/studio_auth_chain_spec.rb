# frozen_string_literal: true

require 'spec_helper'
require 'base64'
require 'climate_control'
require 'json'
require 'zlib'

# Abuse-path coverage for the live auth chain behind the config studio.
#
# Every example drives a real Rack request through the full middleware stack, so
# a gate that is bypassed at the middleware or routing layer still fails here.
##
# Rack input that records how many bytes anything upstream actually consumed.
class CountingInput < StringIO
  # @return [Integer]
  attr_reader :bytes_read

  # @param string [String]
  def initialize(string)
    super
    @bytes_read = 0
  end

  # @return [String, nil]
  def read(...)
    super.tap { @bytes_read += it.to_s.bytesize }
  end
end

RSpec.describe 'api/v1 studio auth chain', openapi: false, type: :request do
  include Rack::Test::Methods

  # Restricted account from config/feeds.yml; admin is allowlisted for "*".
  let(:member_token) { 'CHANGE_ME_DEMO_TOKEN' }
  let(:member_url) { 'https://news.ycombinator.com' }
  let(:outside_url) { 'https://evil.example/articles' }
  let(:selectors) { { items: { selector: 'article' } } }

  def app = Html2rss::Web::App.freeze.app

  def json_post(path, payload, token: nil)
    header 'Authorization', "Bearer #{token}" if token
    header 'Content-Type', 'application/json'
    post path, payload.to_json
  end

  def error_message(response) = JSON.parse(response.body).dig('error', 'message')

  # Signs a token directly so the example can bind a URL the create endpoint
  # would have refused, which is the state left behind by an allowlist change.
  def mint(username, url, selectors: nil, expires_in: 3600)
    Html2rss::Web::Auth.generate_feed_token(username, url, selectors:, expires_in:)
  end

  def unpack(encoded) = JSON.parse(Zlib::Inflate.inflate(Base64.urlsafe_decode64(encoded)), symbolize_names: true)
  def pack(document) = Base64.urlsafe_encode64(Zlib::Deflate.deflate(JSON.generate(document)))

  describe 'broken access control' do
    it 'refuses to serve a feed token bound to a URL outside the account allowlist' do
      get "/api/v1/feeds/#{mint('demo', outside_url)}"

      expect(last_response.status).to eq(403)
    end

    it 'refuses to preview a URL outside the account allowlist' do
      json_post '/api/v1/feeds/preview', { url: outside_url, selectors: }, token: member_token

      expect(last_response.status).to eq(403)
      expect(error_message(last_response)).to eq('URL not allowed for this account')
    end

    it 'refuses to suggest selectors for a URL outside the account allowlist' do
      json_post '/api/v1/feeds/suggest_selectors', { url: outside_url }, token: member_token

      expect(last_response.status).to eq(403)
      expect(error_message(last_response)).to eq('URL not allowed for this account')
    end

    it 'rejects a valid token replayed under another username' do
      document = unpack(mint('demo', member_url))
      document[:p][:u] = 'admin'

      get "/api/v1/feeds/#{pack(document)}"

      expect(last_response.status).to eq(401)
    end

    it 'does not reach a static feed by putting its name in the token route' do
      get '/api/v1/feeds/example'

      expect(last_response.status).to eq(401)
    end
  end

  describe 'cryptographic integrity' do
    before { allow(Html2rss).to receive(:feed_result).and_call_original }

    it 'rejects a flipped byte in the signed selectors payload and never fetches', :aggregate_failures do
      signed = mint('demo', member_url, selectors: Html2rss::Web::SelectorsDocument.from_client({ selectors: }))
      document = unpack(signed)
      document[:p][:c][:selectors][:items][:selector] = 'aRticle'

      get "/api/v1/feeds/#{pack(document)}"

      expect(last_response.status).to eq(401)
      expect(Html2rss).not_to have_received(:feed_result)
    end

    it 'rejects an expired token' do
      get "/api/v1/feeds/#{mint('demo', member_url, expires_in: -60)}"

      expect(last_response.status).to eq(401)
    end

    it 'does not run gem schema validation before the signature check' do
      allow(Html2rss::Config).to receive(:validate).and_call_original
      unsigned = pack(
        p: { u: 'demo', l: member_url, e: Time.now.to_i + 3600, c: { selectors: } },
        s: 'forged-signature'
      )

      get "/api/v1/feeds/#{unsigned}"

      expect(Html2rss::Config).not_to have_received(:validate)
    end

    it 'answers 401 rather than 500 for an undecodable token' do
      get '/api/v1/feeds/not-a-token-at-all'

      expect(last_response.status).to eq(401)
    end
  end

  describe 'denial of service' do
    it 'discards a compression bomb instead of inflating it', :aggregate_failures do
      bomb = Base64.urlsafe_encode64(
        Zlib::Deflate.deflate({ p: { u: 'demo', l: member_url, e: 1, pad: 'A' * 20_000_000 }, s: 'x' }.to_json, 9)
      )

      expect(Html2rss::Web::FeedToken::Codec.decode(bomb)).to be_nil
      expect(bomb.bytesize).to be > Html2rss::Web::FeedToken::MAX_ENCODED_BYTES
    end

    it 'rejects an oversized encoded token' do
      get "/api/v1/feeds/#{'A' * (Html2rss::Web::FeedToken::MAX_ENCODED_BYTES + 1)}"

      expect(last_response.status).to eq(401)
    end

    it 'rejects an oversized form body without reading it', :aggregate_failures do
      body = "x=#{'A' * (200 * 1024)}"
      input = CountingInput.new(body)
      status, = app.call(
        Rack::MockRequest.env_for(
          '/api/v1/feeds/validate',
          method: 'POST', input:, 'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
          'CONTENT_LENGTH' => body.bytesize.to_s, 'HTTP_AUTHORIZATION' => "Bearer #{member_token}"
        )
      )

      expect(body.bytesize).to be > Html2rss::Web::Api::V1::JsonBody::MAX_BODY_BYTES
      expect(status).to eq(400)
      expect(input.bytes_read).to eq(0)
    end

    it 'rejects an oversized items_selector hint' do
      json_post '/api/v1/feeds/suggest_selectors',
                { url: member_url, items_selector: 'a' * 5_000 },
                token: member_token

      expect(last_response.status).to eq(400)
      expect(error_message(last_response)).to eq('items_selector is too long')
    end
  end

  describe 'server-side request forgery' do
    %w[channel headers strategy request].each do |denied|
      it "rejects a selectors document payload carrying #{denied}" do
        json_post '/api/v1/feeds/validate',
                  { denied => { 'url' => 'http://169.254.169.254/' }, 'selectors' => selectors },
                  token: member_token

        expect(last_response.status).to eq(400)
        expect(error_message(last_response)).to eq("#{denied} is not allowed")
      end
    end

    it 'keeps UrlValidator as the only decider of the fetched URL' do
      token = mint('demo', member_url, selectors: Html2rss::Web::SelectorsDocument.from_client({ selectors: }))
      resolved = Html2rss::Web::Feeds::SourceResolver.call(
        Html2rss::Web::Feeds::Contracts::Request.new(target_kind: :token, feed_name: nil, token:, params: {})
      )

      expect(resolved.generator_input[:channel]).to eq(url: member_url)
    end

    it 'reports a root key gate rejection as 400 even when the key name mimics an issue line' do
      json_post '/api/v1/feeds/validate',
                { yaml: "foo [bar: 1\nselectors:\n  items:\n    selector: article\n" },
                token: member_token

      expect(last_response.status).to eq(400)
      expect(error_message(last_response)).to eq('foo [bar is not allowed')
    end

    it 'still reports a schema failure as a structured issue', :aggregate_failures do
      json_post '/api/v1/feeds/validate', { selectors: { items: { selector: 42 } } }, token: member_token

      json = expect_success_response(last_response)
      expect(json.dig('data', 'report', 'success')).to be(false)
      expect(json.dig('data', 'report', 'issues')).not_to be_empty
    end

    it 'reports unparseable yaml as a parse issue rather than a 500' do
      json_post '/api/v1/feeds/validate', { yaml: "selectors: [\n" }, token: member_token

      expect(JSON.parse(last_response.body).dig('data', 'report', 'issues', 0, 'code')).to eq('parse')
    end
  end

  describe 'authentication and misconfiguration' do
    %w[feeds feeds/validate feeds/preview feeds/suggest_selectors].each do |path|
      it "rejects an unauthenticated POST to /api/v1/#{path}" do
        json_post "/api/v1/#{path}", { url: member_url, selectors: }

        expect(last_response.status).to eq(401)
      end
    end

    it 'authenticates before disclosing that the studio is disabled' do
      ClimateControl.modify(STUDIO_ENABLED: 'false') do
        json_post '/api/v1/feeds/validate', { selectors: }
      end

      expect(last_response.status).to eq(401)
    end

    it 'authenticates before disclosing that auto source is disabled' do
      ClimateControl.modify(AUTO_SOURCE_ENABLED: 'false') do
        json_post '/api/v1/feeds/preview', { url: member_url, selectors: }
      end

      expect(last_response.status).to eq(401)
    end

    it 'fails the studio and auto-source flags closed when RACK_ENV is unset', :aggregate_failures do
      ClimateControl.modify(RACK_ENV: nil) do
        expect(Html2rss::Web::Flags.studio_enabled?).to be(false)
        expect(Html2rss::Web::Flags.auto_source_enabled?).to be(false)
      end
    end

    it 'keeps studio route names readable in the audit trail', :aggregate_failures do
      Html2rss::Web::Routes::ApiV1::FeedRoutes::STUDIO_POSTS.each_key do |name|
        expect(Html2rss::Web::LogSanitizer.sanitize_path("/api/v1/feeds/#{name}")).to eq("/api/v1/feeds/#{name}")
      end
      expect(Html2rss::Web::LogSanitizer.sanitize_path("/api/v1/feeds/#{mint('demo', member_url)}"))
        .to eq('/api/v1/feeds/[REDACTED]')
    end
  end
end
