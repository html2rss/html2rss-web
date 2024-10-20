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
