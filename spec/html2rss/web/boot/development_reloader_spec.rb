# frozen_string_literal: true

require 'spec_helper'
require 'zeitwerk'

require_relative '../../../../app/web/boot/development_reloader'

RSpec.describe Html2rss::Web::Boot::DevelopmentReloader do
  let(:loader) { instance_double(Zeitwerk::Loader, reload: nil) }
  let(:rack_app) { ->(_env) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }
  let(:instance) { described_class.new(loader:, app_provider: -> { rack_app }) }

  before do
    stub_const('Html2rss::Web::LocalConfig', Class.new { def self.reload!(reason:); end })
    stub_const('Html2rss::Web::AccountManager', Class.new { def self.reload!(reason:); end })
    allow(Html2rss::Web::LocalConfig).to receive(:reload!)
    allow(Html2rss::Web::AccountManager).to receive(:reload!)
  end

  it 'reloads code and cached config when watched files change', :aggregate_failures do
    previous_mtime = Time.utc(2026, 3, 15, 10, 0, 0)
    updated_mtime = Time.utc(2026, 3, 15, 10, 5, 0)

    instance.instance_variable_set(:@latest_mtime, previous_mtime)
    allow(instance).to receive(:current_mtime).and_return(updated_mtime)

    status, headers, body = instance.call({})

    expect(loader).to have_received(:reload).once
    expect(Html2rss::Web::LocalConfig).to have_received(:reload!).with(reason: 'code_reload').once
    expect(Html2rss::Web::AccountManager).to have_received(:reload!).with(reason: 'code_reload').once
    expect([status, headers['Content-Type'], body.each.to_a]).to eq([200, 'text/plain', ['ok']])
  end

  it 'does not reload when the watched tree is unchanged' do
    current_mtime = Time.utc(2026, 3, 15, 10, 0, 0)

    instance.instance_variable_set(:@latest_mtime, current_mtime)
    allow(instance).to receive(:current_mtime).and_return(current_mtime)

    instance.call({})

    expect(loader).not_to have_received(:reload)
  end
end
