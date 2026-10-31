# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Boot do
  describe '.setup? / .loader' do
    it 'is set up with a memoized loader', :aggregate_failures do
      expect(described_class.setup?).to be(true)
      expect(described_class.loader).to be_a(Zeitwerk::Loader)
      expect(described_class.loader).to equal(described_class.loader)
    end
  end

  describe '.setup!' do
    it 'returns the existing loader once set up without rebuilding' do
      expect(described_class.setup!).to equal(described_class.loader)
    end
  end

  describe '.setup! (first run)' do
    let(:loader) { instance_double(Zeitwerk::Loader, setup: nil, enable_reloading: nil) }

    let!(:original) { %i[@setup @loader].to_h { [it, described_class.instance_variable_get(it)] } }

    before do
      described_class.instance_variable_set(:@setup, false)
      described_class.instance_variable_set(:@loader, loader)
    end

    after { original.each { |name, value| described_class.instance_variable_set(name, value) } }

    it 'sets up the loader once without reloading by default', :aggregate_failures do
      expect(described_class.setup!).to equal(loader)
      expect(described_class.setup?).to be(true)
      expect(loader).to have_received(:setup)
      expect(loader).not_to have_received(:enable_reloading)
    end

    it 'enables reloading when requested' do
      described_class.setup!(reloadable: true)

      expect(loader).to have_received(:enable_reloading)
    end
  end

  describe 'loader configuration' do
    let(:app_root) { File.expand_path('../../../app', __dir__) }
    let(:inflector) { instance_double(Zeitwerk::Inflector, inflect: nil) }
    let(:fresh) do
      instance_double(Zeitwerk::Loader, push_dir: nil, collapse: nil, inflector:)
    end

    before { allow(Zeitwerk::Loader).to receive(:new).and_return(fresh) }

    it 'returns the configured loader, mapping app/ onto the Html2rss namespace', :aggregate_failures do
      expect(described_class.send(:build_loader)).to equal(fresh)
      expect(described_class.send(:app_root)).to eq(app_root)
      expect(fresh).to have_received(:push_dir).with(app_root, namespace: Html2rss)
    end

    it 'collapses exactly the flat utility directories', :aggregate_failures do
      described_class.send(:build_loader)
      dirs = %w[config errors request security telemetry].map { File.join(app_root, 'web', it) }

      expect(described_class.send(:collapsed_web_dirs)).to eq(dirs)
      dirs.each { |dir| expect(fresh).to have_received(:collapse).with(dir) }
      expect(fresh).to have_received(:collapse).exactly(dirs.size).times
    end

    it 'inflects api_v1 as ApiV1' do
      described_class.send(:build_loader)

      expect(inflector).to have_received(:inflect).with('api_v1' => 'ApiV1')
    end
  end

  describe '.eager_load! / .reload!' do
    it 'delegate to the loader', :aggregate_failures do
      loader = instance_double(Zeitwerk::Loader, eager_load: :loaded, reload: :reloaded)
      allow(described_class).to receive(:loader).and_return(loader)

      expect(described_class.eager_load!).to eq(:loaded)
      expect(described_class.reload!).to eq(:reloaded)
    end
  end
end
