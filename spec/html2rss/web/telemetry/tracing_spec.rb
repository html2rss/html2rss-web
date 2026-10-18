# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

class TracingInstallConfig
  attr_reader :processors, :uses

  def initialize
    @processors = []
    @uses = []
  end

  def add_span_processor(processor) = (@processors << processor)

  def use(name, configuration = nil) = (@uses << [name, configuration])
end

class RecordedSdkConfig
  attr_reader :service_names, :service_versions

  def initialize
    @service_names = []
    @service_versions = []
  end

  def service_name=(value)
    @service_names << value
  end

  def service_version=(value)
    @service_versions << value
  end
end

# rubocop:disable RSpec/MultipleDescribes
RSpec.describe Html2rss::Web::Telemetry::Tracing::AttributeProcessor do
  it 'keeps method, status, peer host, error type, and product attributes' do
    expect(finish_span(kept_attributes)).to include(expected_kept)
  end

  it 'drops urls, paths, query, route, headers, body, and statements', :aggregate_failures do
    attributes = finish_span(dropped_attributes)

    expect(attributes.keys & unsafe_keys).to be_empty
    expect(attributes['peer.service']).to eq('scraper.example')
  end

  it 'copies the request route group onto a server span' do
    Html2rss::Web::RequestContext.set!(request_context('catalog'))

    expect(finish_span({})).to include('html2rss.route_group' => 'catalog')
  ensure
    Html2rss::Web::RequestContext.clear!
  end

  it 'does not replace a route group the span already set' do
    Html2rss::Web::RequestContext.set!(request_context('catalog'))

    attributes = finish_span({ 'html2rss.route_group' => 'feed_render' })

    expect(attributes['html2rss.route_group']).to eq('feed_render')
  ensure
    Html2rss::Web::RequestContext.clear!
  end

  it 'does not copy the route group onto a client span' do
    Html2rss::Web::RequestContext.set!(request_context('catalog'))

    expect(finish_span({}, kind: :client)).not_to have_key('html2rss.route_group')
  ensure
    Html2rss::Web::RequestContext.clear!
  end

  def finish_span(attributes, kind: :server)
    span = Struct.new(:kind, :attributes).new(kind, attributes)
    described_class.new.on_finishing(span)
    span.attributes
  end

  def kept_attributes
    {
      'http.method' => 'GET',
      'http.status_code' => 204,
      'server.address' => 'feeds.example',
      'peer.service' => 'https://user:secret@scraper.example/path?q=1',
      'error.type' => StandardError.new('timed out'),
      'html2rss.operation' => 'feed.render',
      'html2rss.result' => 'failure',
      'html2rss.reason' => 'scraper_unavailable'
    }
  end

  def expected_kept
    {
      'http.request.method' => 'GET', 'http.method' => 'GET',
      'http.response.status_code' => 204, 'http.status_code' => 204,
      'server.address' => 'feeds.example', 'peer.service' => 'scraper.example',
      'error.type' => 'StandardError', 'html2rss.operation' => 'feed.render',
      'html2rss.result' => 'failure', 'html2rss.reason' => 'scraper_unavailable'
    }
  end

  def unsafe_keys
    %w[
      url.full url.path url.query http.route http.request.header.authorization
      http.request.body db.statement
    ]
  end

  def dropped_attributes
    {
      'url.full' => 'https://example.test/api/v1/feeds/token?x=1',
      'url.path' => '/api/v1/feeds/token',
      'url.query' => 'x=1',
      'http.route' => '/api/v1/feeds/:token',
      'http.request.header.authorization' => 'secret',
      'http.request.body' => 'body',
      'db.statement' => 'select 1',
      'peer.service' => 'https://scraper.example/search?q=secret'
    }
  end

  def request_context(route_group)
    Html2rss::Web::RequestContext::Context.new(
      request_id: 'req',
      path: '/api/v1/configs',
      http_method: 'GET',
      route_group: route_group,
      actor: nil,
      strategy: nil,
      started_at: '2026-01-01T00:00:00Z'
    )
  end
end

RSpec.describe Html2rss::Web::Telemetry::Tracing do
  it 'installs the finish processor and the capture switches', :aggregate_failures do
    config = install_config
    allow(described_class).to receive(:exporter_processor).and_return(:batch)

    described_class.install(config)

    expect(config.processors[0]).to be_a(described_class::AttributeProcessor)
    expect(config.processors[1]).to eq(:batch)
    expect(config.uses).to eq(expected_instrumentation)
  end

  it 'leaves the app unwrapped until tracing is active' do
    app = Object.new
    allow(Html2rss::Web::Telemetry::Boot).to receive(:tracing?).and_return(false)

    expect(described_class.wrap(app)).to be(app)
  end

  def install_config = TracingInstallConfig.new

  def expected_instrumentation
    [
      ['OpenTelemetry::Instrumentation::Rack', { allowed_request_headers: [], allowed_response_headers: [] }],
      ['OpenTelemetry::Instrumentation::Faraday', { enable_internal_instrumentation: false }],
      ['OpenTelemetry::Instrumentation::Net::HTTP', {}]
    ]
  end
end

RSpec.describe Html2rss::Web::Telemetry::Boot do
  before do
    described_class.send(:reset!)
    allow(described_class).to receive(:register_exit_hook)
    allow(Html2rss::Web::Telemetry::Metrics).to receive(:start!)
  end

  after { described_class.send(:reset!) }

  it 'does not load the SDK when the endpoint is blank' do
    allow(described_class).to receive(:load_sdk!)

    ClimateControl.modify('OTEL_EXPORTER_OTLP_ENDPOINT' => nil) do
      described_class.start!
    end

    expect(described_class).not_to have_received(:load_sdk!)
  end

  it 'starts metrics when the endpoint is blank' do
    ClimateControl.modify('OTEL_EXPORTER_OTLP_ENDPOINT' => nil) do
      described_class.start!
    end

    expect(Html2rss::Web::Telemetry::Metrics).to have_received(:start!)
  end

  it 'configures once per process and again for a new pid', :aggregate_failures do
    configurator = record_configure
    allow(Process).to receive(:pid).and_return(11, 11, 22, 22)

    ClimateControl.modify(endpoint_env) do
      described_class.start!
      described_class.start!
      described_class.start!
    end

    expect(configurator.service_names).to eq(%w[html2rss-web html2rss-web])
    expect(described_class).to have_received(:register_exit_hook).twice
  end

  it 'uses the service name and build version', :aggregate_failures do
    configurator = record_configure
    allow(Html2rss::Web::RuntimeEnv).to receive_messages(build_tag: '2026-03-27', git_sha: 'abc1234')

    ClimateControl.modify(endpoint_env.merge('OTEL_SERVICE_NAME' => 'feeds')) do
      described_class.start!
    end

    expect(configurator.service_names).to eq(['feeds'])
    expect(configurator.service_versions).to eq(['2026-03-27+abc1234'])
  end

  it 'defaults a blank sampler and protocol to tracecontext', :aggregate_failures do
    record_configure

    ClimateControl.modify(endpoint_env) do
      described_class.start!
      expect(ENV.fetch('OTEL_TRACES_SAMPLER')).to eq('parentbased_traceidratio')
      expect(ENV.fetch('OTEL_TRACES_SAMPLER_ARG')).to eq('0.1')
      expect(ENV.fetch('OTEL_EXPORTER_OTLP_PROTOCOL')).to eq('http/protobuf')
      expect(ENV.fetch('OTEL_PROPAGATORS')).to eq('tracecontext')
    end
  end

  it 'keeps an explicit sampler' do
    record_configure

    ClimateControl.modify(endpoint_env.merge('OTEL_TRACES_SAMPLER' => 'always_on')) do
      described_class.start!

      expect(ENV.fetch('OTEL_TRACES_SAMPLER')).to eq('always_on')
    end
  end

  def record_configure
    configurator = RecordedSdkConfig.new
    sdk = Module.new
    sdk.define_singleton_method(:configure) { |&block| block.call(configurator) }
    stub_sdk(sdk)
    configurator
  end

  def stub_sdk(sdk)
    stub_const('OpenTelemetry::SDK', sdk)
    allow(described_class).to receive(:load_sdk!)
    allow(Html2rss::Web::Telemetry::Tracing).to receive(:install)
  end

  def endpoint_env
    {
      'OTEL_EXPORTER_OTLP_ENDPOINT' => 'http://127.0.0.1:4318',
      'OTEL_TRACES_SAMPLER' => nil,
      'OTEL_TRACES_SAMPLER_ARG' => nil,
      'OTEL_EXPORTER_OTLP_PROTOCOL' => nil,
      'OTEL_PROPAGATORS' => nil,
      'OTEL_SERVICE_NAME' => nil
    }
  end
end
# rubocop:enable RSpec/MultipleDescribes
