# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

require_relative '../../../app'

RSpec.describe Html2rss::Web::App do
  it { expect(described_class).to be < Roda }

  context 'with Rack::Test' do
    include Rack::Test::Methods

    def app = described_class

    it 'responds to /' do
      get '/'
      expect(last_response).to be_ok
    end

    it 'sets CSP headers' do
      get '/'

      expect(last_response.headers['Content-Security-Policy']).to eq <<~HEADERS.gsub(/\n\s*/, ' ')
        default-src 'none';
        style-src 'self' 'unsafe-inline';
        script-src 'self' 'unsafe-inline';
        connect-src 'self';
        img-src 'self' data: blob:;
        font-src 'self' data:;
        form-action 'self';
        base-uri 'none';
        frame-ancestors 'none';
        frame-src 'none';
        object-src 'none';
        media-src 'none';
        manifest-src 'none';
        worker-src 'none';
        child-src 'none';
        block-all-mixed-content;
        upgrade-insecure-requests;
      HEADERS
    end

    it 'sets security headers' do
      get '/'

      expect(last_response.headers['Strict-Transport-Security']).to eq 'max-age=31536000; includeSubDomains; preload'
      expect(last_response.headers['Cross-Origin-Embedder-Policy']).to eq 'require-corp'
      expect(last_response.headers['Cross-Origin-Opener-Policy']).to eq 'same-origin'
      expect(last_response.headers['Cross-Origin-Resource-Policy']).to eq 'same-origin'
    end
  end

  describe '.development?' do
    subject { described_class.development? }

    around do |example|
      ClimateControl.modify(RACK_ENV: env) { example.run }
    end

    context 'when RACK_ENV is development' do
      let(:env) { 'development' }

      it { is_expected.to be true }
    end

    context 'when RACK_ENV is not development' do
      let(:env) { 'test' }

      it { is_expected.to be false }
    end
  end
end
