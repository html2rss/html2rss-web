# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/health_check'

RSpec.describe App::HealthCheck::Auth do
  before do
    allow(ENV).to receive(:delete).with(any_args).and_call_original
  end

  describe '.username' do
    it {
      expect(described_class.username).to be_a String
      expect(ENV).to have_received(:delete).with('HEALTH_CHECK_USERNAME').once
    }
  end

  describe '.password' do
    it {
      expect(described_class.password).to be_a String
      expect(ENV).to have_received(:delete).with('HEALTH_CHECK_PASSWORD').once
    }
  end
end
