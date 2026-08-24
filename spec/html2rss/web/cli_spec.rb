# frozen_string_literal: true

require 'stringio'
require_relative '../../../app'
require_relative '../../../app/web/cli'

RSpec.describe Html2rss::Web::CLI do
  describe '.run' do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }

    context 'with root help and version commands' do
      it 'prints root help for help options', :aggregate_failures do
        exit_code = described_class.run(['--help'], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(stdout.string).to include('Usage: html2rss-web [command] [options]')
        expect(stdout.string).to include('registry status')
      end

      it 'prints root help when argv is empty', :aggregate_failures do
        exit_code = described_class.run([], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(stdout.string).to include('Usage: html2rss-web [command] [options]')
      end

      it 'prints version and runtime info', :aggregate_failures do
        exit_code = described_class.run(['version'], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(stdout.string).to match(/html2rss-web build=.* sha=.* ruby=.*/)
      end

      it 'handles unknown commands', :aggregate_failures do
        exit_code = described_class.run(['invalid-cmd'], out: stdout, err: stderr)
        expect(exit_code).to eq(1)
        expect(stderr.string).to include('Unknown command: "invalid-cmd"')
      end
    end

    context 'with healthcheck command' do
      let(:success_response) { instance_double(Net::HTTPSuccess, is_a?: true) }
      let(:error_response) { instance_double(Net::HTTPInternalServerError, is_a?: false, code: '500') }

      it 'returns 0 when HTTP healthcheck succeeds', :aggregate_failures do
        allow(Net::HTTP).to receive(:get_response).and_return(success_response)

        exit_code = described_class.run(['healthcheck'], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(stdout.string).to include('OK')
      end

      it 'returns 1 when HTTP healthcheck returns non-200', :aggregate_failures do
        allow(Net::HTTP).to receive(:get_response).and_return(error_response)

        exit_code = described_class.run(['healthcheck'], out: stdout, err: stderr)
        expect(exit_code).to eq(1)
        expect(stderr.string).to include('Healthcheck failed: HTTP 500')
      end

      it 'returns 1 when HTTP connection fails', :aggregate_failures do
        allow(Net::HTTP).to receive(:get_response).and_raise(Errno::ECONNREFUSED)

        exit_code = described_class.run(['healthcheck'], out: stdout, err: stderr)
        expect(exit_code).to eq(1)
        expect(stderr.string).to include('Healthcheck failed')
      end
    end

    context 'with registry subcommands' do
      it 'prints registry help for --help', :aggregate_failures do
        exit_code = described_class.run(%w[registry --help], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(stdout.string).to include('Usage: html2rss-web registry [subcommand]')
      end

      it 'prints registry status table', :aggregate_failures do
        exit_code = described_class.run(%w[registry status], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(stdout.string).to include("registry\tmode\tversion\tstaged_version\tupdated_at\tsync_url\tlast_error")
        expect(stdout.string).to include('official')
      end

      it 'runs registry sync', :aggregate_failures do
        allow(Html2rss::Web::Registry::Sync).to receive_messages(run: nil, cli_exit_code: 0)

        exit_code = described_class.run(%w[registry sync --registry official --dry-run], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(Html2rss::Web::Registry::Sync).to have_received(:run).with(registry_id: 'official', dry_run: true)
      end

      it 'runs registry promote', :aggregate_failures do
        allow(Html2rss::Web::Registry::Sync).to receive_messages(promote_staged!: nil, cli_exit_code: 0)

        exit_code = described_class.run(%w[registry promote --registry official], out: stdout, err: stderr)
        expect(exit_code).to eq(0)
        expect(Html2rss::Web::Registry::Sync).to have_received(:promote_staged!).with(registry_id: 'official')
      end

      it 'handles unknown registry subcommands', :aggregate_failures do
        exit_code = described_class.run(%w[registry invalid-sub], out: stdout, err: stderr)
        expect(exit_code).to eq(1)
        expect(stderr.string).to include('Unknown registry command: "invalid-sub"')
      end
    end
  end
end
