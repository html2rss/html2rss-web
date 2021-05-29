# frozen_string_literal: true

require 'spec_helper'
require_relative '../../app/health_check'

RSpec.describe App::HealthCheck do
  describe '.run' do
    context 'without errors' do
      before do
        allow(described_class).to receive(:errors).and_return([])
      end

      it { expect(described_class.run).to eq 'success' }
    end

    context 'with errors' do
      before do
        allow(described_class).to receive(:errors).and_return(%w[foo bar])
      end

      it { expect(described_class.run).not_to eq 'success' }
    end
  end

  describe '.errors' do
    it { expect(described_class.errors).to be_a(Array) }
  end
end
