# frozen_string_literal: true

require 'spec_helper'
require 'rss'
require 'roda'
require 'base64'
require_relative '../../../../helpers/auto_source'

describe Html2rss::Web::AutoSource do # rubocop:disable RSpec/SpecFilePathFormat
  context 'when ENV variables are not set' do
    describe '.enabled?' do
      subject { described_class.enabled? }

      it { is_expected.to be false }
    end

    describe '.username' do
      it 'raises an error' do
        expect { described_class.username }.to raise_error(KeyError)
      end
    end

    describe '.password' do
      it 'raises an error' do
        expect { described_class.password }.to raise_error(KeyError)
      end
    end

    describe '.allowed_origins' do
      subject { described_class.allowed_origins }

      it { is_expected.to eq Set[] }
    end
  end

  context 'when ENV variables are set' do
    around do |example|
      ClimateControl.modify AUTO_SOURCE_ENABLED: 'true',
                            AUTO_SOURCE_USERNAME: 'foo',
                            AUTO_SOURCE_PASSWORD: 'bar',
                            AUTO_SOURCE_ALLOWED_ORIGINS: 'localhost,example.com, ' do
        example.run
      end
    end

    describe '.username' do
      subject { described_class.username }

      it { is_expected.to eq 'foo' }
    end

    describe '.password' do
      subject { described_class.password }

      it { is_expected.to eq 'bar' }
    end

    describe '.allowed_origins' do
      subject { described_class.allowed_origins }

      it { is_expected.to eq Set['localhost', 'example.com'] }
    end
  end

  describe '.ttl_in_seconds' do
    subject { described_class.ttl_in_seconds(rss, default_in_minutes: 60) }

    context 'when rss.channel.ttl is present' do
      let(:rss) do
        instance_double(RSS::Rss, channel: instance_double(RSS::Rss::Channel, ttl: 2))
      end

      it { is_expected.to eq 120 }
    end

    context 'when rss.channel.ttl is not present' do
      let(:rss) do
        nil
      end

      it { is_expected.to eq 3600 }
    end
  end

  # rubocop:disable RSpec/NamedSubject, RSpec/MessageSpies
  describe '.check_request_origin!' do
    subject { described_class.check_request_origin!(request, response, allowed_origins) }

    let(:request) { instance_double(Roda::RodaRequest, env: { 'HTTP_HOST' => 'localhost' }, halt: nil) }
    let(:response) { instance_double(Roda::RodaResponse, write: nil, 'status=': nil) }
    let(:allowed_origins) { Set['localhost'] }

    context 'when origin is allowed' do
      it { is_expected.to be_nil }
    end

    context 'when allowed_origins is empty' do
      let(:allowed_origins) { Set[] }

      it 'writes a message to the response' do
        message = 'No allowed origins are configured. Please set AUTO_SOURCE_ALLOWED_ORIGINS.'
        expect(response).to receive(:write).with(message)
        subject
      end
    end

    context 'when origin is not allowed' do
      let(:request) { instance_double(Roda::RodaRequest, env: { 'HTTP_HOST' => 'example.com' }, halt: nil) }

      it 'writes a message to the response' do
        expect(response).to receive(:write).with('Origin is not allowed.')
        subject
      end

      it 'sets the response status to 403' do
        expect(response).to receive(:status=).with(403)
        subject
      end

      it 'halts the request' do
        expect(request).to receive(:halt)
        subject
      end
    end

    context 'when origin is not allowed and X-Forwarded-Host is set' do
      let(:request) { instance_double(Roda::RodaRequest, env: { 'HTTP_X_FORWARDED_HOST' => 'example.com' }, halt: nil) }

      it 'writes a message to the response' do
        expect(response).to receive(:write).with('Origin is not allowed.')
        subject
      end
    end

    context 'when origin is not allowed and both HTTP_HOST and X-Forwarded-Host are set' do
      let(:request) do
        instance_double(Roda::RodaRequest,
                        env: { 'HTTP_HOST' => 'proxy.example.com',
                               'HTTP_X_FORWARDED_HOST' => 'example.com' },
                        halt: nil)
      end

      it 'writes a message to the response' do
        expect(response).to receive(:write).with('Origin is not allowed.')
        subject
      end
    end
  end
  # rubocop:enable RSpec/NamedSubject, RSpec/MessageSpies

  describe '.build_auto_source_from_encoded_url' do
    subject(:feed) do
      VCR.use_cassette('auto_source-github-h2r-web', match_requests_on: %i[method path]) do
        described_class.build_auto_source_from_encoded_url(encoded_url)
      end
    end

    let(:encoded_url) { Base64.urlsafe_encode64('https://github.com/html2rss/html2rss-web/commits/master') }

    it 'returns an RSS::Rss object' do
      expect(feed).to be_a(RSS::Rss)
    end
  end
end
