# frozen_string_literal: true

require 'spec_helper'

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

    it 'sets CSP headers' do # rubocop:disable RSpec/ExampleLength
      get '/'

      expect(last_response.headers['Content-Security-Policy']).to eq <<~HEADERS.gsub(/\n\s*/, ' ')
        default-src 'none';
        style-src 'self';
        script-src 'self';
        connect-src 'self';
        img-src 'self';
        font-src 'self' data:;
        form-action 'self';
        base-uri 'none';
        frame-ancestors 'self';
        frame-src 'self';
        block-all-mixed-content;
      HEADERS
    end
  end

  describe '.development?' do
    subject { described_class.development? }

    context 'when RACK_ENV is development' do
      before { ENV['RACK_ENV'] = 'development' }

      it { is_expected.to be true }
    end

    context 'when RACK_ENV is not development' do
      before { ENV['RACK_ENV'] = 'test' }

      it { is_expected.to be false }
    end
  end
end
