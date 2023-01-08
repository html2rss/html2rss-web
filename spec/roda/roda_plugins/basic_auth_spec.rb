# frozen_string_literal: true

require 'spec_helper'
require 'rack'
require_relative '../../../roda/roda_plugins/basic_auth'

RSpec.describe Roda::RodaPlugins::BasicAuth do
  before do
    allow(Roda::RodaPlugins).to receive(:register_plugin).with(:basic_auth, described_class)
  end

  describe '.authorize(username, password, auth)' do
    context 'with correct credentials' do
      it {
        username = 'foo'
        password = 'bar'
        auth = instance_double(Rack::Auth::Basic::Request, credentials: %w[foo bar])

        expect(described_class.authorize(username, password, auth)).to be true
      }
    end

    context 'with wrong credentials' do
      it {
        username = ''
        password = ''
        auth = instance_double(Rack::Auth::Basic::Request, credentials: %w[foo bar])

        expect(described_class.authorize(username, password, auth)).to be false
      }
    end
  end

  describe '.secure_compare(left, right)' do
    context 'with left being same as right' do
      let(:left) {  'something-asdf' }
      let(:right) { 'something-asdf' }

      it 'uses OpenSSL.fixed_length_secure_compare', :aggregate_failures do
        allow(OpenSSL).to receive(:fixed_length_secure_compare).with(left, right).and_call_original

        expect(described_class.secure_compare(left, right)).to be true

        expect(OpenSSL).to have_received(:fixed_length_secure_compare).with(left, right)
      end
    end

    context 'with left being different from right' do
      it 'returns false', :aggregate_failures do
        expect(described_class.secure_compare('left', 'right')).to be false
        expect(described_class.secure_compare('lefty', 'right')).to be false
      end
    end
  end
end
