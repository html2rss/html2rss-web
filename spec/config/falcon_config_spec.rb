# frozen_string_literal: true

require 'climate_control'
require 'tempfile'
require_relative '../../config/falcon'

RSpec.describe FalconConfig do
  describe '.project_root' do
    it 'returns the repository root directory' do
      expect(described_class.project_root).to eq(File.expand_path('../..', __dir__))
    end
  end

  describe '.rackup_file' do
    it 'returns the path to config.ru' do
      expect(described_class.rackup_file).to eq(File.join(described_class.project_root, 'config.ru'))
    end
  end

  describe '.worker_count' do
    it 'returns 1 in development environment' do
      ClimateControl.modify('RACK_ENV' => 'development', 'WEB_CONCURRENCY' => '4') do
        expect(described_class.worker_count).to eq(1)
      end
    end

    it 'returns WEB_CONCURRENCY when in production environment' do
      ClimateControl.modify('RACK_ENV' => 'production', 'WEB_CONCURRENCY' => '4') do
        expect(described_class.worker_count).to eq(4)
      end
    end

    it 'defaults to 2 in production when WEB_CONCURRENCY is not set' do
      ClimateControl.modify('RACK_ENV' => 'production', 'WEB_CONCURRENCY' => nil) do
        expect(described_class.worker_count).to eq(2)
      end
    end
  end

  describe '.timeout_seconds' do
    it 'defaults to 55 seconds' do
      ClimateControl.modify('REQUEST_TIMEOUT_SECONDS' => nil) do
        expect(described_class.timeout_seconds).to eq(55.0)
      end
    end

    it 'respects REQUEST_TIMEOUT_SECONDS override' do
      ClimateControl.modify('REQUEST_TIMEOUT_SECONDS' => '30') do
        expect(described_class.timeout_seconds).to eq(30.0)
      end
    end
  end

  describe '.endpoint' do
    context 'when TLS certificate or key path is not provided' do
      it 'returns an HTTP endpoint' do
        ClimateControl.modify('PORT' => '4000', 'TLS_CERTIFICATE_PATH' => nil, 'TLS_KEY_PATH' => nil) do
          endpoint = described_class.endpoint
          expect(endpoint.scheme).to eq('http')
          expect(endpoint.port).to eq(4000)
        end
      end
    end

    context 'when TLS certificate and key files exist' do
      let(:cert_file) { Tempfile.new(['cert', '.pem']) }
      let(:key_file) { Tempfile.new(['key', '.pem']) }
      let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
      let(:cert) do
        OpenSSL::X509::Certificate.new.tap do |c|
          c.version = 2
          c.serial = 1
          c.subject = OpenSSL::X509::Name.parse('/CN=localhost')
          c.issuer = c.subject
          c.public_key = rsa_key.public_key
          c.not_before = Time.now - 3600
          c.not_after = Time.now + 3600
          c.sign(rsa_key, OpenSSL::Digest.new('SHA256'))
        end
      end

      before do
        key_file.write(rsa_key.to_pem)
        key_file.flush
        cert_file.write(cert.to_pem)
        cert_file.flush
      end

      after do
        cert_file.close!
        key_file.close!
      end

      it 'returns an HTTPS endpoint with hardened TLS options and ciphers', :aggregate_failures do
        ClimateControl.modify('PORT' => '4443', 'TLS_CERTIFICATE_PATH' => cert_file.path,
                              'TLS_KEY_PATH' => key_file.path) do
          endpoint = described_class.endpoint
          expect(endpoint.scheme).to eq('https')
          expect(endpoint.port).to eq(4443)
          ssl_context = endpoint.ssl_context
          expect(ssl_context).to be_a(OpenSSL::SSL::SSLContext)
          cipher_names = ssl_context.ciphers.map(&:first)
          expect(cipher_names).to include('ECDHE-RSA-AES128-GCM-SHA256')
          expect(ssl_context.options & OpenSSL::SSL::OP_NO_COMPRESSION).not_to be_zero
        end
      end
    end
  end
end
