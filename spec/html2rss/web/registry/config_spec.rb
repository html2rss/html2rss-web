# frozen_string_literal: true

require 'fileutils'
require 'climate_control'
require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::Config do
  describe '.entry' do
    let(:config_path) { File.join(Dir.pwd, 'tmp', 'missing-public-key-registries.yml') }

    before do
      FileUtils.mkdir_p(File.dirname(config_path))
      File.write(config_path, <<~YAML)
        precedence:
          - official
        registries:
          official:
            sync:
              url: https://registry.test.example/registry-bundle.tar.gz
            catalog: true
      YAML
    end

    after do
      FileUtils.rm_f(config_path)
    end

    it 'requires a pinned public key for sync-mode registries' do
      ClimateControl.modify('REGISTRIES_CONFIG' => config_path) do
        expect do
          described_class.reload!
          described_class.entry('official')
        end.to raise_error(Html2rss::Web::Registry::Errors::ConfigError, /requires a pinned public_key/)
      end
    end
  end

  describe 'sync policy parsing' do
    let(:config_path) { File.join(Dir.pwd, 'tmp', 'sync-policy-registries.yml') }

    before do
      FileUtils.mkdir_p(File.dirname(config_path))
      File.write(config_path, <<~YAML)
        precedence:
          - official
        registries:
          official:
            sync:
              channel: html2rss-official
              pin_version: v2026.08.22
              max_version: v2026.08.21
            auto_promote: true
            allowed_channel_domains:
              - phys.org
            catalog: true
            public_key_id: html2rss:registry:2026
            public_key: |
              -----BEGIN PUBLIC KEY-----
              MCowBQYDK2VwAyEAiMbg/04MyC5azBdM/aeY0mNuA8JbP5/jOiNRwJ2KJHE=
              -----END PUBLIC KEY-----
      YAML
    end

    after do
      FileUtils.rm_f(config_path)
    end

    it 'parses sync policy and domain allowlist fields', :aggregate_failures do
      ClimateControl.modify('REGISTRIES_CONFIG' => config_path) do
        described_class.reload!
        entry = described_class.entry('official')

        expect(entry.sync_policy).to have_attributes(
          pin_version: 'v2026.08.22',
          max_version: 'v2026.08.21',
          auto_promote: true
        )
        expect(entry.allowed_channel_domains).to eq(['phys.org'])
      end
    end

    it 'defaults auto_promote to false for security' do
      ClimateControl.modify('REGISTRIES_CONFIG' => nil) do
        described_class.reload!
        entry = described_class.entry('official')

        expect(entry.sync_policy.auto_promote).to be(false)
      end
    end
  end
end
