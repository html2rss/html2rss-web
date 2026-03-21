# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../../app'

RSpec.describe Html2rss::Web::Boot::Setup do
  before do
    allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_environment!)
    allow(Html2rss::Web::EnvironmentValidator).to receive(:validate_production_security!)
    allow(Html2rss::Web::Flags).to receive(:validate!)
  end

  describe '.call!' do
    it 'validates environment state', :aggregate_failures do
      described_class.call!

      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_environment!).once
      expect(Html2rss::Web::EnvironmentValidator).to have_received(:validate_production_security!).once
      expect(Html2rss::Web::Flags).to have_received(:validate!).once
    end

    it 'routes rack-timeout logs through the shared app logger' do
      stub_const('Rack::Timeout::Logger', Class.new)
      logger_holder = { value: nil }
      Rack::Timeout::Logger.define_singleton_method(:logger=) { |value| logger_holder[:value] = value }
      Rack::Timeout::Logger.define_singleton_method(:logger) { logger_holder[:value] }

      described_class.call!

      expect(Rack::Timeout::Logger.logger).to be(Html2rss::Web::AppLogger.logger)
    end
  end
end
