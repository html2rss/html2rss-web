# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

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

  describe '.run', :registry_sync do
    let(:download_url) { 'https://registry.test.example/registry-bundle.tar.gz' }
    let(:tarball) { RegistrySyncTestHelpers.build_signed_tarball }

    before do
      stub_request(:get, download_url)
        .to_return(status: 200, body: tarball, headers: { 'Content-Type' => 'application/octet-stream' })
    end

    it 'fetches, verifies, and stores a signed bundle', :aggregate_failures do
      status = described_class.run(registry_id: 'official')

      expect(status.version).to eq('test-fixture')
      expect(Html2rss::Web::Registry::Store.bundle_present?('official')).to be(true)
      expect(Html2rss::Web::Registry::Index.current.config_for('phys.org/weekly')).to include(
        channel: hash_including(title: 'Phys.org — Weekly')
      )
    end

    it 'supports dry-run verification without swapping the active bundle' do
      expect do
        described_class.run(registry_id: 'official', dry_run: true)
      end.not_to(change { Html2rss::Web::Registry::Store.bundle_present?('official') })
    end

    it 'rejects redirects' do
      stub_request(:get, download_url)
        .to_return(status: 302, headers: { 'Location' => 'https://evil.example/bundle.tar.gz' })

      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError, /redirect/i)
    end

    it 'logs signature verification failures to the security logger' do
      allow(Html2rss::Web::SecurityLogger).to receive(:log_registry_signature_failure)
      stub_request(:get, download_url).to_return(status: 200, body: 'not-a-tarball')

      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError)

      expect(Html2rss::Web::SecurityLogger).not_to have_received(:log_registry_signature_failure)
    end

    it 'keeps the previous bundle when sync fails' do
      described_class.run(registry_id: 'official')
      stub_request(:get, download_url).to_return(status: 500, body: 'fail')

      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError, /HTTP 500/)

      expect(Html2rss::Web::Registry::Store.bundle_present?('official')).to be(true)
    end
  end

  describe '.run' do
    it 'rejects path-mode registries' do
      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError, /path mode/)
    end
  end

  describe '.status', :registry_sync do
    it 'includes sync metadata and last error state' do
      row = described_class.status(registry_id: 'official').first

      expect(row).to have_attributes(
        registry_id: 'official',
        mode: :sync,
        sync_url: 'https://registry.test.example/registry-bundle.tar.gz'
      )
    end
  end

  describe '.cli_exit_code', :registry_sync do
    it 'returns non-zero when a sync registry has no bundle' do
      expect(described_class.cli_exit_code).to eq(1)
    end

    it 'returns zero after a successful sync' do
      stub_request(:get, 'https://registry.test.example/registry-bundle.tar.gz')
        .to_return(status: 200, body: RegistrySyncTestHelpers.build_signed_tarball)

      described_class.run(registry_id: 'official')

      expect(described_class.cli_exit_code).to eq(0)
    end
  end

  describe '.boot!' do
    it 'does not run in the test environment' do
      allow(described_class).to receive(:seed_registry!)
      allow(described_class).to receive(:start_background_timer!)

      described_class.boot!

      expect(described_class).not_to have_received(:seed_registry!)
    end
  end
end
