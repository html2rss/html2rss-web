# frozen_string_literal: true

require 'fileutils'
require 'stringio'
require 'climate_control'
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

      it 'verifies valid registry bundles', :aggregate_failures do
        exit_code = described_class.run(
          ['registry', 'verify', '--registry', 'official', '--dir', 'spec/fixtures/registries/official'],
          out: stdout,
          err: stderr
        )
        expect(exit_code).to eq(0)
        expect(stdout.string).to include("Verified registry bundle 'official' (test-fixture)")
      end

      it 'reports failure on invalid registry verification', :aggregate_failures do
        exit_code = described_class.run(
          ['registry', 'verify', '--registry', 'official', '--dir', 'tmp/non-existent'],
          out: stdout,
          err: stderr
        )
        expect(exit_code).to eq(1)
        expect(stderr.string).to include('Registry verification failed')
      end

      it 'handles unknown registry subcommands', :aggregate_failures do
        exit_code = described_class.run(%w[registry invalid-sub], out: stdout, err: stderr)
        expect(exit_code).to eq(1)
        expect(stderr.string).to include('Unknown registry command: "invalid-sub"')
      end
    end

    context 'with registry add' do
      let(:local_root) { File.join(Dir.pwd, 'tmp', 'cli-local-registry') }
      let(:config_path) { File.join(Dir.pwd, 'tmp', 'cli-local-registries.yml') }

      before do
        FileUtils.rm_rf(local_root)
        FileUtils.mkdir_p(File.dirname(config_path))
        File.write(config_path, <<~YAML)
          precedence:
            - local
          registries:
            local:
              path: #{local_root}
              catalog: false
        YAML
      end

      after do
        FileUtils.rm_rf(local_root)
        FileUtils.rm_f(config_path)
      end

      def with_local_registry(&)
        ClimateControl.modify('REGISTRIES_CONFIG' => config_path) do
          Html2rss::Web::Registry::Index.reload!
          yield
        end
      end

      def write_feed(path, id:, title: 'Example') # rubocop:disable Metrics/MethodLength
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, <<~YAML)
          registry:
            id: #{id}
          directory:
            title: #{title}
          channel:
            url: https://example.com/#{id}
            title: #{title}
          selectors:
            items:
              selector: article
            title:
              selector: h1
            url:
              extractor: href
        YAML
      end

      def run_add(path)
        described_class.run(['registry', 'add', path], out: stdout, err: stderr)
      end

      it 'accepts one valid feed file', :aggregate_failures do
        feed = File.join(Dir.pwd, 'tmp', 'cli-add-feed.yml')
        write_feed(feed, id: 'example.com/feed')

        with_local_registry do
          expect(run_add(feed)).to eq(0)
          expect(stdout.string).to include('example.com/feed', local_root)
          expect(Html2rss::Web::Registry::Index.current.config_for('example.com/feed'))
            .to include(channel: hash_including(title: 'Example'))
        end
      ensure
        FileUtils.rm_f(feed)
      end

      it 'rejects missing registry.id', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
        feed = File.join(Dir.pwd, 'tmp', 'cli-add-missing-id.yml')
        File.write(feed, <<~YAML)
          channel:
            url: https://example.com/feed
            title: Example
          selectors:
            items:
              selector: article
            title:
              selector: h1
            url:
              extractor: href
        YAML

        with_local_registry do
          expect(run_add(feed)).to eq(1)
          expect(stderr.string).to match(/registry\.id|Registry add failed/)
          expect(File).not_to exist(File.join(local_root, 'manifest.json'))
        end
      ensure
        FileUtils.rm_f(feed)
      end

      it 'rejects invalid YAML', :aggregate_failures do
        feed = File.join(Dir.pwd, 'tmp', 'cli-add-invalid.yml')
        File.write(feed, "registry:\n  id: [broken")

        with_local_registry do
          expect(run_add(feed)).to eq(1)
          expect(stderr.string).to include('Registry add failed')
        end
      ensure
        FileUtils.rm_f(feed)
      end

      it 'upserts the same registry.id', :aggregate_failures do
        feed = File.join(Dir.pwd, 'tmp', 'cli-add-upsert.yml')
        write_feed(feed, id: 'example.com/feed', title: 'First')

        with_local_registry do
          run_add(feed)
          write_feed(feed, id: 'example.com/feed', title: 'Second')
          expect(run_add(feed)).to eq(0)
          expect(Html2rss::Web::Registry::Index.current.config_for('example.com/feed'))
            .to include(channel: hash_including(title: 'Second'))
        end
      ensure
        FileUtils.rm_f(feed)
      end

      it 'leaves the previous bundle when a directory add fails', :aggregate_failures do
        dir = File.join(Dir.pwd, 'tmp', 'cli-add-dir')
        good = File.join(dir, 'good.yml')
        write_feed(good, id: 'example.com/good', title: 'Keep Me')

        with_local_registry do
          run_add(good)
          File.write(File.join(dir, 'bad.yml'), "registry:\n  id: [broken")
          expect(run_add(dir)).to eq(1)
          expect(Html2rss::Web::Registry::Index.current.config_for('example.com/good'))
            .to include(channel: hash_including(title: 'Keep Me'))
        end
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end
end
