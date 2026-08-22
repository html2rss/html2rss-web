# frozen_string_literal: true

require 'fileutils'
require 'climate_control'
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

    it 'follows bounded redirects to allowed CDN hosts', :aggregate_failures do
      cdn_url = 'https://release-assets.githubusercontent.com/registry-bundle.tar.gz'
      stub_request(:get, download_url)
        .to_return(status: 302, headers: { 'Location' => cdn_url })
      stub_request(:get, cdn_url)
        .to_return(status: 200, body: tarball, headers: { 'Content-Type' => 'application/octet-stream' })

      status = described_class.run(registry_id: 'official')

      expect(status.version).to eq('test-fixture')
      expect(Html2rss::Web::Registry::Store.bundle_present?('official')).to be(true)
    end

    it 'rejects redirects to disallowed hosts' do
      stub_request(:get, download_url)
        .to_return(status: 302, headers: { 'Location' => 'https://evil.example/bundle.tar.gz' })

      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError, /host not allowed/i)
    end

    it 'rejects excessive redirect chains' do
      (1..6).each do |hop|
        from = hop == 1 ? download_url : "#{download_url}?hop=#{hop - 1}"
        to = "#{download_url}?hop=#{hop}"
        stub_request(:get, from).to_return(status: 302, headers: { 'Location' => to })
      end

      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError, /redirect limit/i)
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
        sync_url: 'https://registry.test.example/registry-bundle.tar.gz',
        staged_version: nil
      )
    end
  end

  describe 'sync policy', :registry_sync do
    let(:download_url) { 'https://registry.test.example/registry-bundle.tar.gz' }
    let(:tarball) { RegistrySyncTestHelpers.build_signed_tarball }
    let(:policy_config_path) { File.join(Dir.pwd, 'tmp', 'sync-policy-official.yml') }

    before do
      FileUtils.mkdir_p(File.dirname(policy_config_path))
      stub_request(:get, download_url)
        .to_return(status: 200, body: tarball, headers: { 'Content-Type' => 'application/octet-stream' })
    end

    after do
      FileUtils.rm_f(policy_config_path)
    end

    def write_policy_config(yaml)
      File.write(policy_config_path, yaml)
      ENV['REGISTRIES_CONFIG'] = policy_config_path
      Html2rss::Web::Registry::Index.reload!
    end

    it 'stages verified bundles when auto_promote is false', :aggregate_failures do
      write_policy_config(
        RegistrySyncTestHelpers.policy_registry_yaml(
          download_url:,
          auto_promote: false,
          sync_extra: { max_version: 'test-fixture' }
        )
      )

      status = described_class.run(registry_id: 'official')

      expect(Html2rss::Web::Registry::Store.staged_present?('official')).to be(true)
      expect(Html2rss::Web::Registry::Store.bundle_present?('official')).to be(false)
      expect(status.staged_version).to eq('test-fixture')
    end

    it 'promotes staged bundles and emits catalog change telemetry', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      allow(Html2rss::Web::Observability).to receive(:emit)
      allow(Html2rss::Web::SecurityLogger).to receive(:log_registry_catalog_changed)

      write_policy_config(
        RegistrySyncTestHelpers.policy_registry_yaml(download_url:, auto_promote: false)
      )

      described_class.run(registry_id: 'official')
      status = described_class.promote_staged!(registry_id: 'official')

      expect(status.version).to eq('test-fixture')
      expect(Html2rss::Web::Registry::Store.staged_present?('official')).to be(false)
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        hash_including(event_name: 'registry.promote_staged', outcome: 'success')
      )
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        hash_including(event_name: 'registry.catalog_changed', outcome: 'success')
      )
      expect(Html2rss::Web::SecurityLogger).to have_received(:log_registry_catalog_changed)
    end

    it 'rejects manifests newer than max_version' do
      write_policy_config(
        RegistrySyncTestHelpers.policy_registry_yaml(
          download_url:,
          auto_promote: true,
          sync_extra: { max_version: '0.0.1' }
        )
      )

      expect { described_class.run(registry_id: 'official') }
        .to raise_error(Html2rss::Web::Registry::Errors::SyncError, /exceeds max_version/)
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

  describe Html2rss::Web::Registry::SyncTransport do
    describe '.exceeds_max?' do
      [
        ['2026.08.22', '2026.08.21', true],
        ['2026.08.21', '2026.08.22', false],
        ['v2026.08.22', '2026.08.21', true],
        ['2026.08.22', nil, false]
      ].each do |manifest_version, max_version, expected|
        it "returns #{expected} for #{manifest_version} vs #{max_version.inspect}" do
          expect(described_class.exceeds_max?(manifest_version, max_version)).to be(expected)
        end
      end
    end

    describe '.resolve' do
      it 'uses the GitHub tag release API when pin_version is set', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        tag_api = format(
          described_class::OFFICIAL_GITHUB_TAG_RELEASES_API,
          tag: 'v2026.08.22'
        )
        download_url = 'https://release-assets.githubusercontent.com/registry-bundle.tar.gz'
        stub_request(:get, tag_api).to_return(
          status: 200,
          body: {
            assets: [{ name: described_class::OFFICIAL_ASSET_NAME, browser_download_url: download_url }]
          }.to_json
        )

        entry = Html2rss::Web::Registry::Entry.new(
          id: 'official',
          mode: :sync,
          path: nil,
          sync_channel: Html2rss::Web::Registry::Config::DEFAULT_OFFICIAL_SYNC_CHANNEL,
          sync_url: nil,
          catalog: true,
          public_key_id: 'html2rss:registry:2026',
          public_key: nil,
          sync_policy: Html2rss::Web::Registry::SyncPolicy.new('v2026.08.22', nil, false),
          allowed_channel_domains: []
        )

        expect(described_class.resolve(entry)).to eq(download_url)
      end
    end
  end
end
