# frozen_string_literal: true

require 'falcon/environment/rack'
require 'openssl'

##
# Helper for building endpoints and options for Falcon.
module FalconConfig
  class << self
    def project_root
      File.expand_path('..', __dir__)
    end

    def rackup_file
      File.join(project_root, 'config.ru')
    end

    def worker_count
      ENV['RACK_ENV'] == 'development' ? 1 : Integer(ENV.fetch('WEB_CONCURRENCY', 2))
    end

    def timeout_seconds
      Float(ENV.fetch('REQUEST_TIMEOUT_SECONDS', 15))
    end

    def endpoint
      port = ENV.fetch('PORT', 4000)
      cert_path = ENV.fetch('TLS_CERTIFICATE_PATH', nil)
      key_path = ENV.fetch('TLS_KEY_PATH', nil)

      if cert_path && !cert_path.empty? && key_path && !key_path.empty? &&
         File.exist?(cert_path) && File.exist?(key_path)
        tls_endpoint(port, cert_path, key_path)
      else
        Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
      end
    end

    private

    def tls_endpoint(port, cert_path, key_path)
      Async::HTTP::Endpoint.parse(
        "https://0.0.0.0:#{port}",
        ssl_context: OpenSSL::SSL::SSLContext.new.tap do |context|
          context.cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
          context.key = OpenSSL::PKey.read(File.read(key_path))
          context.alpn_protocols = ['h2', 'http/1.1']
        end
      )
    end
  end
end

service 'html2rss-web' do
  include Falcon::Environment::Rack

  root { FalconConfig.project_root }
  rackup_path { FalconConfig.rackup_file }

  count { FalconConfig.worker_count }
  timeout { FalconConfig.timeout_seconds }
  endpoint { FalconConfig.endpoint }
end
