# frozen_string_literal: true

require 'fileutils'
require 'climate_control'
require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Registry::ScrapePolicy do
  let(:allowed_entry) do
    Html2rss::Web::Registry::Entry.new(
      id: 'official',
      mode: :path,
      path: nil,
      sync_channel: nil,
      sync_url: nil,
      catalog: true,
      public_key_id: 'test',
      public_key: nil,
      sync_policy: Html2rss::Web::Registry::SyncPolicy.new(nil, nil, false),
      allowed_channel_domains: ['phys.org']
    )
  end

  let(:allowed_bundle) do
    Html2rss::Web::Registry::Index::RegistryBundle.new(
      registry_id: 'official',
      manifest: instance_double(Html2rss::Registry::Manifest, version: '1.0.0'),
      configs: {
        'phys.org/weekly' => { channel: { url: 'https://phys.org/weekly-news/' } }
      },
      catalog_entries: []
    )
  end

  let(:blocked_bundle) do
    Html2rss::Web::Registry::Index::RegistryBundle.new(
      registry_id: 'official',
      manifest: instance_double(Html2rss::Registry::Manifest, version: '1.0.0'),
      configs: {
        'phys.org/weekly' => { channel: { url: 'https://phys.org/weekly-news/' } },
        'blocked.example/feed' => { channel: { url: 'https://blocked.example/private' } }
      },
      catalog_entries: []
    )
  end

  it 'allows suffix-matching channel domains' do
    expect { described_class.enforce!(allowed_entry, allowed_bundle) }.not_to raise_error
  end

  it 'raises when a config channel domain is not allowlisted' do
    expect { described_class.enforce!(allowed_entry, blocked_bundle) }
      .to raise_error(Html2rss::Web::Registry::Errors::LoadError, /blocked.example/)
  end
end
