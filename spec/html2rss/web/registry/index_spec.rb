# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::Index do
  describe '#config_for' do
    it 'returns registry configs by feed id' do
      config = described_class.current.config_for('support.apple.com/en_gb_ht201222')

      expect(config).to include(channel: hash_including(title: 'Apple Support — Security releases'))
    end

    it 'returns nil for unknown ids' do
      expect(described_class.current.config_for('missing.example/feed')).to be_nil
    end

    it 'still resolves catalog-disabled registry feeds by id' do
      config = described_class.current.config_for('secret.example/private')

      expect(config).to include(channel: hash_including(url: 'https://secret.example/private'))
    end
  end

  describe '#catalog_rows' do
    it 'includes registry rows with source and registry fields' do
      rows = described_class.current.catalog_rows
      phys = rows.find { |row| row.fetch(:id) == 'phys.org/weekly' }

      expect(phys).to include(
        source: 'registry',
        registry: 'official',
        path: '/phys.org/weekly.rss'
      )
    end

    it 'omits catalog-disabled registries from the catalog API rows' do
      rows = described_class.current.catalog_rows

      expect(rows.map { |row| row.fetch(:id) }).not_to include('secret.example/private')
    end
  end

  describe '#status' do
    it 'reports loaded registry metadata' do
      status = described_class.current.status
      official = status.find { |entry| entry.id == 'official' }

      expect(official).to have_attributes(
        version: 'test-fixture',
        sync_mode: :path
      )
    end
  end
end
