# frozen_string_literal: true

require 'spec_helper'
require 'rack/request'
require_relative '../../../../app/request_path'

RSpec.describe Html2rss::Web::RequestPath do
  subject(:instance) { described_class.new(request) }

  context 'with a local config' do
    let(:request) { instance_double(Rack::Request, path: '/example.rss') }

    describe '#full_config_name' do
      it { expect(instance.full_config_name).to eq 'example' }
    end

    describe '#config_name' do
      it { expect(instance.config_name).to eq 'example' }
    end

    describe '#extension' do
      it { expect(instance.extension).to eq 'rss' }
    end
  end

  context 'with a html2rss-config' do
    let(:request) { instance_double(Rack::Request, path: '/github.com/releases.rss') }

    describe '#full_config_name' do
      it { expect(instance.full_config_name).to eq 'github.com/releases' }
    end

    describe '#config_name' do
      it { expect(instance.config_name).to eq 'releases' }
    end

    describe '#extension' do
      it { expect(instance.extension).to eq 'rss' }
    end
  end
end
