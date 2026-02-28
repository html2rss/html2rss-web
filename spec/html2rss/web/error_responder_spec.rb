# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

require_relative '../../../app'

RSpec.describe Html2rss::Web::ErrorResponder do
  let(:rack_errors) { StringIO.new }
  let(:request_env) { { 'rack.errors' => rack_errors } }
  let(:response) { Rack::Response.new }
  let(:request) { Struct.new(:path, :env).new(path, request_env) }

  describe '.respond' do
    context 'when request path is under api v1' do
      let(:path) { '/api/v1/feeds' }

      it 'returns json error payload for unexpected errors', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        body = described_class.respond(request: request, response: response, error: StandardError.new('boom'))

        expect(response.status).to eq(500)
        expect(response['Content-Type']).to eq('application/json')
        expect(JSON.parse(body)).to eq(
          'success' => false,
          'error' => {
            'code' => Html2rss::Web::Api::V1::Contract::CODES[:internal_server_error],
            'message' => 'Internal Server Error'
          }
        )
      end
    end

    context 'when request path is not under api v1' do
      let(:path) { '/legacy' }

      it 'returns xml error payload', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        allow(Html2rss::Web::XmlBuilder).to receive(:build_error_feed).and_return('<error/>')

        body = described_class.respond(request: request, response: response,
                                       error: Html2rss::Web::InternalServerError.new('oops'))

        expect(response.status).to eq(500)
        expect(response['Content-Type']).to eq('application/xml')
        expect(body).to eq('<error/>')
      end
    end
  end
end
