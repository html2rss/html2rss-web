# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

PRODUCT_VIEW = [
  'stdout JSON',
  'GET /metrics',
  'html2rss.operation',
  'html2rss.result',
  'html2rss.reason',
  'A null `trace_id` is an unsampled line or a line outside a span.',
  'increase(html2rss_outcome_total{result="failure"}[15m])',
  'This repo does not create that alert.',
  '/api/v1/health/live',
  'does not load config',
  '/api/v1/health/ready',
  'LocalConfig.load_snapshot',
  'HEALTH_CHECK_TOKEN',
  '`/metrics` is not a restart signal.',
  'one JSON object per line',
  'trailing newline',
  '`trace_id` stays inside the body',
  'does not send `stream-name`',
  'Phase 04',
  'feed.render',
  'feed.create',
  'request.fault',
  'catalog.build',
  'Render subscribed feed',
  'Create hosted feed',
  'Read catalog',
  'Instance health'
].freeze

RSpec.describe 'telemetry operator contract' do
  let(:root) { File.expand_path('../../../..', __dir__) }
  let(:readme) { File.read(File.join(root, 'docs/README.md')) }
  let(:env_example) { File.read(File.join(root, '.env.example')) }
  let(:compose_text) { File.read(File.join(root, 'docker-compose.yml')) }
  let(:compose) { YAML.safe_load(compose_text) }

  it 'names the operator keys in the env sample, flags table, and compose' do
    keys = %w[
      OTEL_EXPORTER_OTLP_ENDPOINT OTEL_EXPORTER_OTLP_PROTOCOL OTEL_SERVICE_NAME
      OTEL_TRACES_SAMPLER OTEL_TRACES_SAMPLER_ARG PROMETHEUS_MULTIPROC_DIR HEALTH_CHECK_TOKEN
    ]
    missing = keys.reject { |key| readme.include?(key) && env_example.include?(key) && compose_text.include?(key) }

    expect(missing).to be_empty
  end

  it 'drops Sentry log intake from the operator surfaces' do
    expect([readme, env_example, compose_text]).to all(satisfy { |text| !text.include?('SENTRY_ENABLE_LOGS') })
  end

  it 'passes OpenTelemetry variables through empty except the protocol default' do
    environment = compose.dig('services', 'html2rss-web', 'environment')

    expect(environment).to include(
      'OTEL_EXPORTER_OTLP_ENDPOINT' => '${OTEL_EXPORTER_OTLP_ENDPOINT:-}',
      'OTEL_EXPORTER_OTLP_PROTOCOL' => '${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}',
      'OTEL_SERVICE_NAME' => '${OTEL_SERVICE_NAME:-}',
      'OTEL_TRACES_SAMPLER' => '${OTEL_TRACES_SAMPLER:-}',
      'OTEL_TRACES_SAMPLER_ARG' => '${OTEL_TRACES_SAMPLER_ARG:-}',
      'PROMETHEUS_MULTIPROC_DIR' => '${PROMETHEUS_MULTIPROC_DIR:-}'
    )
  end

  it 'keeps json-file logs and the service label on the web service' do
    web = compose.dig('services', 'html2rss-web')

    expect(web['logging']).to eq(
      'driver' => 'json-file',
      'options' => { 'max-size' => '10m', 'max-file' => '3', 'labels' => 'service' }
    )
    expect(web['labels']).to eq('service' => 'html2rss-web')
  end

  it 'leaves the scraper without that log driver' do
    botasaurus = compose.dig('services', 'botasaurus')

    expect(botasaurus).not_to have_key('logging')
    expect(botasaurus.dig('environment', 'SENTRY_DSN')).to include('BOTASAURUS_SENTRY_DSN')
  end

  it 'does not add a collector, host scraper, database, or OpenObserve service' do
    expect(compose.fetch('services').keys).to eq(%w[html2rss-web botasaurus])
  end

  it 'names the product series' do
    expect(readme).to include('html2rss_up', 'html2rss_build_info', 'html2rss_outcome_total{operation,result,reason}')
  end

  it 'names every closed outcome reason' do
    reasons = Html2rss::Web::Telemetry::ALLOWED.map(&:last).uniq
    missing = reasons.reject { |reason| readme.include?(reason) }

    expect(missing).to be_empty
  end

  it 'names the single scrape target' do
    expect(readme).to include('only `:4000/metrics`')
  end

  it 'names the live probe command' do
    expect(readme).to include('`bin/docker-healthcheck`')
  end

  it 'lists the signals that are not collected' do
    signals = [
      'host CPU', 'memory', 'disk', 'network', 'visitor analytics', 'per-user streams',
      'URLs', 'tokens', 'bodies', 'SQL', 'raw paths', 'queue depth', 'botasaurus traces',
      'OTEL metrics', 'OTEL logs'
    ]
    missing = signals.reject { |signal| readme.include?(signal) }

    expect(missing).to be_empty
  end

  it 'states the product view for traces, probes, and the collector line' do
    missing = PRODUCT_VIEW.reject { |phrase| readme.include?(phrase) }

    expect(missing).to be_empty
  end
end
