# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::Strategies do
  describe '.index' do
    def listing(registered)
      allow(Html2rss::RequestService).to receive(:strategy_registered?) { |name| registered.include?(name) }
      described_class.index(nil)
    end

    it 'lists registered public strategies with display names and a total', :aggregate_failures do
      payload = listing(%i[default botasaurus])

      expect(payload.dig(:data, :strategies)).to eq(
        [{ id: 'default', name: 'default', display_name: 'Default' },
         { id: 'botasaurus', name: 'botasaurus', display_name: 'Browser (Botasaurus)' }]
      )
      expect(payload[:meta]).to eq(total: 2)
    end

    it 'omits unregistered strategies and never exposes non-public ones', :aggregate_failures do
      payload = listing(%i[default faraday])

      expect(payload.dig(:data, :strategies).map { it[:id] }).to eq(%w[default])
      expect(payload[:meta]).to eq(total: 1)
    end

    it 'returns an empty list when nothing is registered' do
      expect(listing([])).to include(data: { strategies: [] }, meta: { total: 0 })
    end

    it 'restricts the public list to default and botasaurus' do
      expect(described_class::PUBLIC_STRATEGIES).to eq(%i[default botasaurus])
    end
  end

  describe 'display names' do
    it 'humanizes unknown strategy names', :aggregate_failures do
      expect(described_class.send(:display_name_for, :my_cool_strategy)).to eq('My Cool Strategy')
      expect(described_class.send(:display_name_for, 'single')).to eq('Single')
    end
  end
end
