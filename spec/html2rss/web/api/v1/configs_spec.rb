# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::Configs do
  let(:entry) { instance_double(Html2rss::Web::Catalog::Entry, to_h: { id: 'a' }) }

  before do
    allow(Html2rss::Web::Catalog::Merge).to receive(:call).and_return([entry, entry])
    allow(Html2rss::Web::Catalog::Starters).to receive(:pick).and_return(%w[a])
    allow(Html2rss::Web::Observability).to receive(:emit)
  end

  describe '.index' do
    it 'wraps wire entries with total, catalog version and starters', :aggregate_failures do
      payload = described_class.index(nil)

      expect(payload.dig(:data, :configs)).to eq([{ id: 'a' }, { id: 'a' }])
      expect(payload[:meta]).to eq(total: 2, catalog_version: 2, starters: %w[a])
      expect(described_class::CATALOG_VERSION).to eq(2)
      expect(Html2rss::Web::Catalog::Starters).to have_received(:pick).with([entry, entry])
    end

    it 'emits a success event with the entry count and rounded duration', :aggregate_failures do
      clock = [10.0, 10.0123]
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock.shift }
      described_class.index(nil)

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'catalog.build', outcome: 'success', details: { count: 2, duration_ms: 12 }
      )
    end

    it 'emits a warn failure event and re-raises a missing directory title', :aggregate_failures do
      error = Html2rss::Configs::Catalog::MissingDirectoryTitle.new('no title')
      allow(Html2rss::Web::Catalog::Merge).to receive(:call).and_raise(error)

      expect { described_class.index(nil) }.to raise_error(error)
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'catalog.build', outcome: 'failure', level: :warn, details: { reason: 'no title' }
      )
    end

    it 'does not swallow other errors' do
      allow(Html2rss::Web::Catalog::Merge).to receive(:call).and_raise(ArgumentError, 'x')

      expect { described_class.index(nil) }.to raise_error(ArgumentError)
    end
  end
end
