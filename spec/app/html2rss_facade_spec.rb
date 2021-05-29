# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/html2rss_facade'

RSpec.describe App::Html2rssFacade do
  describe '.from_config(name, typecast_params, &block)' do
    let(:typecast_params) do
      double({}, str!: nil) # rubocop:disable RSpec/VerifiedDoubles
    end

    let(:name) { Html2rss::Configs.file_names.first.split('/')[-2..].join('/').split('.')[0..-2].join('.') }

    before do
      allow(typecast_params).to receive(:str!)
      allow(Html2rss).to receive(:feed)
    end

    context 'without dynamic params' do
      it do
        described_class.from_config(name, typecast_params)
        expect(typecast_params).not_to have_received(:str!)
      end
    end

    it 'yields a Html2rss::Config' do
      expect { |b| described_class.from_config(name, typecast_params, &b) }.to yield_with_args
    end
  end
end
