# frozen_string_literal: true

require 'spec_helper'
require 'rss'
require_relative '../../app'
require 'html2rss'

RSpec.describe Html2rss::Web::App do # rubocop:disable RSpec/SpecFilePathFormat
  include Rack::Test::Methods
  def app = described_class

  let(:request_headers) do
    { 'HTTP_HOST' => 'localhost' }
  end
  let(:encoded_url) { Base64.urlsafe_encode64('https://github.com/html2rss/html2rss-web/commits/master') }

  let(:username) { 'username' }
  let(:password) { 'password' }

  let(:feed) do
    RSS::Maker.make('2.0') do |maker|
      maker.channel.title = 'title'
      maker.channel.link = 'link'
      maker.channel.description = 'description'
    end
  end

  before do
    allow(Html2rss::Web::AutoSource).to receive_messages(enabled?: true,
                                                         username:,
                                                         password:,
                                                         allowed_origins: Set['localhost'])
  end

  describe "GET '/auto_source/'" do
    context 'without provided basic auth' do
      it 'sets header "www-authenticate" in response', :aggregate_failures do
        get '/auto_source/', {}, request_headers

        expect(last_response.has_header?('www-authenticate')).to be true
        expect(last_response).to be_unauthorized
      end
    end

    context 'with provided basic auth' do
      it 'responds successfully to /auto_source/', :aggregate_failures do
        get '/auto_source/', {},
            request_headers.merge('HTTP_AUTHORIZATION' => basic_authorize(username, password))

        expect(last_response).to be_ok
        expect(last_response.body).to include('<h1>Auto Source</h1>') &
                                      include('<iframe loading="lazy"></iframe>')
      end
    end

    context 'when request origin is not allowed' do
      it 'responds with 403 Forbidden' do
        get '/auto_source/', {},
            request_headers.merge('HTTP_AUTHORIZATION' => basic_authorize(username, password),
                                  'HTTP_HOST' => 'http://example.com')

        expect(last_response).to be_forbidden
      end
    end
  end

  describe "GET '/auto_source/:encoded_url'" do
    context 'with provided basic auth' do
      subject(:response) do
        VCR.use_cassette('auto_source-github-h2r-web') do
          get "/auto_source/#{encoded_url}?strategy",
              {},
              request_headers.merge('HTTP_AUTHORIZATION' => basic_authorize(username, password))
        end
      end

      it 'responds successfully', :aggregate_failures do
        expect(response).to be_ok
        expect(response.body).to start_with '<?xml version="1.0" encoding="UTF-8"?>'
        expect(response.get_header('cache-control')).to eq 'must-revalidate, private, max-age=0'
        expect(response.get_header('content-type')).to eq described_class::CONTENT_TYPE_RSS
      end
    end

    context 'when strategy is not registered' do
      subject(:response) do
        VCR.use_cassette('auto_source-github-h2r-web', match_requests_on: [:path]) do
          get "/auto_source/#{encoded_url}?strategy=nope",
              {},
              request_headers.merge('HTTP_AUTHORIZATION' => basic_authorize(username, password))
        end
      end

      it 'responds with Error', :aggregate_failures do
        expect(response.status).to eq 422
        expect(response.body).to match(/UnknownStrategy/)
      end
    end
  end

  context 'when auto_source feature is disabled' do
    before do
      allow(Html2rss::Web::AutoSource).to receive(:enabled?).and_return(false)
    end

    describe "GET '/auto_source/'" do
      it 'responds with 400 Bad Request' do
        get '/auto_source/', {},
            request_headers.merge('HTTP_AUTHORIZATION' => basic_authorize(username, password))

        expect(last_response).to be_bad_request
      end
    end

    describe "GET '/auto_source/:encoded_url'" do
      it 'responds with 400 Bad Request', :aggregate_failures do
        get "/auto_source/#{encoded_url}",
            {},
            request_headers.merge('HTTP_AUTHORIZATION' => basic_authorize(username, password))

        expect(last_response).to be_bad_request
        expect(last_response.body).to eq 'The auto source feature is disabled.'
      end
    end
  end
end
