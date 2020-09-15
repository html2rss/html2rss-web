task default: %w[test]

task :test do
  current_dir = ENV['TRAVIS_BUILD_DIR'] || __dir__

  sh 'docker build -t gilcreator/html2rss-web -f Dockerfile .'
  sh ['docker run -d -p 3000:3000 --mount type=bind,source="',
      current_dir,
      '/config,target=/app/config" --name html2rss-web-test gilcreator/html2rss-web'].join

  # wait for container to run and accept connections
  sleep 5
  sh 'docker ps | grep html2rss-web-test'

  sh 'curl -f http://127.0.0.1:3000/github.com/releases.rss\?username=nuxt\&repository=nuxt.js || exit 1'
  sh 'curl -f http://127.0.0.1:3000/health_check.txt || exit 1'
ensure
  sh 'docker logs html2rss-web-test'
  sh 'docker stop html2rss-web-test'
  sh 'docker rm html2rss-web-test'
end
