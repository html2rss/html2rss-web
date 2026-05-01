# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Boot::Sentry do
  let(:sentry_dsn) { 'https://example@sentry.invalid/1' }
  let(:captured_config) { Struct.new(:dsn, :environment, :enable_logs, :send_default_pii, :release).new }
  let(:captured_scope) do
    Class.new do
      attr_reader :tags

      def initialize
        @tags = {}
      end

      def set_tags(**tags)
        @tags = tags
      end
    end.new
  end
  let(:fake_sentry) do
    config = captured_config
    scope = captured_scope

    Module.new.tap do |mod|
      mod.define_singleton_method(:initialized?) { false }
      mod.define_singleton_method(:init) do |&block|
        block.call(config)
      end
      mod.define_singleton_method(:configure_scope) do |&block|
        block.call(scope)
      end
    end
  end

  before do
    stub_const('Sentry', fake_sentry)
  end

  it 'configures release, environment, and scope tags when a dsn is present', :aggregate_failures do
    stub_runtime_env_for_sentry('production')
    described_class.send(:initialize_sentry!)

    expect_sentry_configuration
  end

  it 'does nothing when a dsn is not present' do
    allow(Html2rss::Web::RuntimeEnv).to receive(:sentry_enabled?).and_return(false)

    expect(described_class.send(:configure?)).to be(false)
  end

  def stub_runtime_env_for_sentry(rack_env)
    allow(Html2rss::Web::RuntimeEnv).to receive_messages(
      sentry_enabled?: true,
      sentry_dsn: sentry_dsn,
      rack_env: rack_env,
      build_tag: '2026-03-27',
      git_sha: 'abc1234',
      sentry_logs_enabled?: false
    )
  end

  def expect_sentry_configuration
    expect(captured_config).to have_attributes(
      dsn: sentry_dsn,
      environment: 'production',
      enable_logs: false,
      send_default_pii: false,
      release: '2026-03-27+abc1234'
    )
    expect_sentry_scope_tags
  end

  def expect_sentry_scope_tags
    expect(captured_scope.tags).to eq(
      release: '2026-03-27+abc1234',
      environment: 'production'
    )
  end
end
