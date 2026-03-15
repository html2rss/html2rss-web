# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'open3'

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

def test_container_exists?(container_name)
  inspection, status = Open3.capture2e('docker', 'inspect', container_name)
  return false unless status.success?
  return false if inspection.strip.empty?

  JSON.parse(inspection).any?
rescue JSON::ParserError
  false
end

task default: %w[test]

desc 'Build and run docker image/container, and send requests to it'

task :test do
  current_dir = ENV.fetch('GITHUB_WORKSPACE', __dir__)
  smoke_auto_source_enabled = ENV.fetch('SMOKE_AUTO_SOURCE_ENABLED', 'false')
  image_name = 'html2rss/web'
  skip_build = ENV.fetch('DOCKER_SMOKE_SKIP_BUILD', 'false') == 'true'

  if skip_build
    Output.describe 'Running with prebuilt docker image'
  else
    Output.describe 'Building and running'
    sh "docker build -t #{image_name} -f Dockerfile ."
  end

  sh ['docker run',
      '-d',
      '-p 4000:4000',
      '--env PUMA_LOG_CONFIG=1',
      '--env HEALTH_CHECK_TOKEN=CHANGE_ME_HEALTH_CHECK_TOKEN',
      '--env HTML2RSS_SECRET_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      "--env AUTO_SOURCE_ENABLED=#{smoke_auto_source_enabled}",
      "--mount type=bind,source=#{current_dir}/config,target=/app/config",
      '--name html2rss-web-test',
      image_name].join(' ')

  Output.wait 10, message: 'Waiting for container to start:'

  Output.describe 'Listing docker containers matching html2rss-web-test filter'
  sh 'docker ps -a --filter name=html2rss-web-test'

  Output.describe 'Running RSpec smoke suite against container'
  smoke_env = {
    'SMOKE_BASE_URL' => 'http://127.0.0.1:4000',
    'SMOKE_HEALTH_TOKEN' => 'CHANGE_ME_HEALTH_CHECK_TOKEN',
    'SMOKE_API_TOKEN' => 'CHANGE_ME_ADMIN_TOKEN',
    'SMOKE_AUTO_SOURCE_ENABLED' => smoke_auto_source_enabled,
    'RUN_DOCKER_SPECS' => 'true'
  }
  sh smoke_env, 'bundle exec rspec --tag docker'
ensure
  if test_container_exists?('html2rss-web-test')
    Output.describe 'Cleaning up test container'

    sh 'docker logs --tail all html2rss-web-test'
    sh 'docker stop html2rss-web-test'
    sh 'docker rm html2rss-web-test'
  end

  exit 1 if $ERROR_INFO
end

namespace :openapi do
  desc 'Generate OpenAPI YAML from request specs'
  task :generate do
    FileUtils.mkdir_p('public')
    FileUtils.rm_f('public/openapi.yaml')
    sh({ 'OPENAPI' => '1' }, 'bundle exec rspec spec/html2rss/web/api/v1_spec.rb --order defined')
  end

  desc 'Verify generated OpenAPI YAML is up to date'
  task verify: :generate do
    sh 'git diff --exit-code -- public/openapi.yaml'
  end
end

namespace :yard do
  desc 'Fail when public methods in app/ are missing essential YARD docs'
  task :verify_public_docs do
    require 'yard'

    files = Dir.glob(File.join(__dir__, 'app/**/*.rb'))
    YARD::Registry.clear
    YARD::Registry.load(files, true)

    violations = []

    YARD::Registry.all(:method).each do |method_object|
      next unless method_object.visibility == :public
      next unless method_object.file&.include?('/app/')

      location = "#{method_object.path} (#{method_object.file}:#{method_object.line})"
      normalize_param_name = lambda do |name|
        name.to_s.sub(/\A[*&]/, '').sub(/:$/, '')
      end

      param_tags = method_object.tags(:param)
      params = method_object.parameters.map(&:first).map { |name| normalize_param_name.call(name) }
      params.reject! { |name| name == 'block' }

      param_tag_names = param_tags.map { |tag| normalize_param_name.call(tag.name) }
      missing_params = params - param_tag_names
      violations << "#{location} missing @param for: #{missing_params.join(', ')}" unless missing_params.empty?

      param_tags.each do |tag|
        violations << "#{location} @param #{tag.name} missing type" if tag.types.nil? || tag.types.empty?
      end

      return_tag = method_object.tag(:return)
      if return_tag.nil?
        violations << "#{location} missing @return"
      elsif return_tag.types.nil? || return_tag.types.empty?
        violations << "#{location} @return missing type"
      end
    end

    if violations.any?
      puts 'YARD public method documentation check failed:'
      violations.sort.each { |violation| puts "  - #{violation}" }
      abort "\nFound #{violations.count} YARD documentation violation(s)."
    end

    puts 'YARD public method documentation check passed.'
  end
end

namespace :zeitwerk do
  desc 'Fail when Zeitwerk cannot eager load the app tree cleanly'
  task :verify do
    ENV['RACK_ENV'] ||= 'test'
    require_relative 'app'

    Html2rss::Web::Boot.eager_load!
    puts 'Zeitwerk eager load check passed.'
  end
end
