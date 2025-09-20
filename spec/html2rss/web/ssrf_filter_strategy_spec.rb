# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/ssrf_filter_strategy'

RSpec.describe Html2rss::Web::SsrfFilterStrategy do
  subject(:instance) { described_class.new(ctx) }

  let(:url) { 'http://example.com' }
  let(:headers) { { 'User-Agent': 'Mozilla/5.0' } }
  let(:ctx) { instance_double(Html2rss::RequestService::Context, url:, headers:) }

  describe '#execute' do
    before do
      allow(SsrfFilter).to receive(:get).with(url, headers:).and_return(
        instance_double(Net::HTTPResponse, body: 'body', to_hash: { 'Content-Type' => ['text/html'] })
      )
    end

    it 'returns a response', :aggregate_failures do
      response = instance.execute

      expect(SsrfFilter).to have_received(:get).with(url, headers:)
      expect(response).to be_a(Html2rss::RequestService::Response)
      expect(response.body).to eq('body')
      expect(response.headers).to eq('Content-Type' => 'text/html')
    end
  end
end
