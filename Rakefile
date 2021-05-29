# frozen_string_literal: true

task default: %w[test]

desc 'Build and run docker image/container, and send requests to it'
task :test do
  current_dir = ENV['GITHUB_WORKSPACE'] || __dir__

  sh 'docker build -t gilcreator/html2rss-web -f Dockerfile .'
  sh ['docker run',
      '-d',
      '-p 3000:3000',
      '--env PUMA_LOG_CONFIG=1',
      "--mount type=bind,source=#{current_dir}/config,target=/app/config",
      '--name html2rss-web-test',
      'gilcreator/html2rss-web'].join(' ')

  # wait for container to run and accept connections
  sleep 5
  sh 'docker ps -a'

  sh 'curl -f http://127.0.0.1:3000/github.com/releases.rss\?username=nuxt\&repository=nuxt.js || exit 1'
  sh 'curl -f http://127.0.0.1:3000/health_check.txt || exit 1'
  sh 'docker exec html2rss-web-test html2rss help'
ensure
  sh 'docker logs --tail all html2rss-web-test'
  sh 'docker stop html2rss-web-test'
  sh 'docker rm html2rss-web-test'
end
