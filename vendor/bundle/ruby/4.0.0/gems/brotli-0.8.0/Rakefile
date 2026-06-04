require "bundler/setup"
require "bundler/gem_tasks"
require "rake/clean"
require "rake/testtask"
require "rake/extensiontask"

CLEAN.include("ext/brotli/common")
CLEAN.include("ext/brotli/dec")
CLEAN.include("ext/brotli/enc")
CLEAN.include("ext/brotli/include")

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = true
  t.verbose = true
end

Rake::ExtensionTask.new("brotli") do |ext|
  ext.lib_dir = "lib/brotli"
end

task build: :compile
task test: :compile
task default: :test

task :docker do
  gcc_versions = ["14", "15"]
  brotli_configs = [true, false]
  gcc_versions.product(brotli_configs).each do |gcc_version, use_system_brotli|
    command = "docker build "\
              "--progress=plain "\
              "--build-arg GCC_VERSION=#{gcc_version} "\
              "--build-arg USE_SYSTEM_BROTLI=#{use_system_brotli} "\
              "-t brotli:#{gcc_version}#{use_system_brotli ? "-use_system_brotli" : ""} ."
    puts "Running: #{command}"
    system command
    unless $?.exited?
      raise "Docker build failed for GCC version #{gcc_version} with use_system_brotli=#{use_system_brotli}"
    end
  end
end
