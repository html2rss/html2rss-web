# frozen_string_literal: true

require 'json'

##
# Helper methods used during :test run
module Output
  module_function

  def describe(msg)
    puts ''
    puts '*' * 80
    puts "* #{msg}"
    puts '*' * 80
    puts ''
  end

  def wait(seconds, message:)
    print message if message

    seconds.times do |i|
      putc ' '
      putc (i + 1).to_s
      sleep 1
    end
    puts '. Time is up.'
  end
end

task default: %w[test]

desc 'Build and run docker image/container, and send requests to it'

task :test do
  current_dir = ENV.fetch('GITHUB_WORKSPACE', __dir__)

  Output.describe 'Building and running'
  sh 'docker build -t gilcreator/html2rss-web -f Dockerfile .'
  sh ['docker run',
      '-d',
      '-p 3000:3000',
      '--env PUMA_LOG_CONFIG=1',
      '--env HEALTH_CHECK_TOKEN=health-check-token-xyz789',
      "--mount type=bind,source=#{current_dir}/config,target=/app/config",
      '--name html2rss-web-test',
      'gilcreator/html2rss-web'].join(' ')

  Output.wait 10, message: 'Waiting for container to start:'

  Output.describe 'Listing docker containers matching html2rss-web-test filter'
  sh 'docker ps -a --filter name=html2rss-web-test'

  Output.describe 'Running RSpec smoke suite against container'
  smoke_env = {
    'SMOKE_BASE_URL' => 'http://127.0.0.1:3000',
    'SMOKE_HEALTH_TOKEN' => 'health-check-token-xyz789',
    'SMOKE_API_TOKEN' => 'allow-any-urls-abcd-4321',
    'RUN_DOCKER_SPECS' => 'true'
  }
  sh smoke_env, 'bundle exec rspec --tag docker'
ensure
  test_container_exists = JSON.parse(`docker inspect html2rss-web-test`).any?

  if test_container_exists
    Output.describe 'Cleaning up test container'

    sh 'docker logs --tail all html2rss-web-test'
    sh 'docker stop html2rss-web-test'
    sh 'docker rm html2rss-web-test'
  end

  exit 1 if $ERROR_INFO
end
