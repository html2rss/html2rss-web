# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/http_cache'

RSpec.describe Html2rss::Web::HttpCache do
  let(:response) { {} }

  describe '.expires(response, seconds, cache_control:)' do
    let(:seconds) { 60 }
    let(:cache_control) { 'something' }

    it do
      expect do
        described_class.expires(response, seconds)
      end.to change(response, :size).by(2)
    end

    it do
      described_class.expires(response, seconds, cache_control:)
      expect(response['Cache-Control']).to eq "max-age=#{seconds},#{cache_control}"
    end
  end

  describe '.expires_now(response)' do
    it do
      expect do
        described_class.expires_now(response)
      end.to change(response, :size).by(2)
    end
  end
end
