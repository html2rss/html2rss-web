# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::Sync do
  describe '.sync_url_for' do
    it 'resolves the official release URL for sync-mode defaults' do
      ClimateControl.modify('REGISTRIES_CONFIG' => nil) do
        Html2rss::Web::Registry::Index.reload!

        expect(described_class.sync_url_for('official')).to eq(
          Html2rss::Web::Registry::Config::OFFICIAL_RELEASE_URL
        )
      end
    end
  end

  describe '.run' do
    it 'rejects path-mode registries' do
      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError, /path mode/)
    end
  end
end
