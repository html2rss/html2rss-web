# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'socket'
require 'timeout'

RSpec.describe 'bin/docker-healthcheck' do
  it 'gets the live probe and sends no authorization header', :aggregate_failures do
    body, status = capture_probe

    expect(status).to be_success
    expect(body).to include('GET /api/v1/health/live')
    expect(body).not_to include('Authorization')
    expect(body).not_to include('secret-token')
  end

  # @return [Array<(String, Process::Status)>]
  def capture_probe
    server = TCPServer.new('127.0.0.1', 0)
    thread = accept_probe(server)
    status = run_healthcheck(server.addr[1])
    [Timeout.timeout(3) { thread.value }, status]
  ensure
    thread&.kill
    server&.close
  end

  # @param server [TCPServer]
  # @return [Thread]
  def accept_probe(server)
    # rubocop:disable-next ThreadSafety/NewThread
    Thread.new do
      client = server.accept
      request = read_headers(client)
      client.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK")
      client.close
      request
    end
  end

  # @param client [TCPSocket]
  # @return [String]
  def read_headers(client)
    request = +''
    request << client.readpartial(1024) until request.include?("\r\n\r\n")
    request
  end

  # @param port [Integer]
  # @return [Process::Status]
  def run_healthcheck(port)
    _out, _err, status = Open3.capture3(
      { 'PORT' => port.to_s, 'HEALTH_CHECK_TOKEN' => 'secret-token', 'TLS_CERTIFICATE_PATH' => '' },
      RbConfig.ruby,
      File.expand_path('../../../bin/docker-healthcheck', __dir__)
    )
    status
  end
end
