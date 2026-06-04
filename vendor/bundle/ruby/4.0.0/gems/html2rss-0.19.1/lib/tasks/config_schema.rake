# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../html2rss'

namespace :config do
  desc 'Generate config JSON schema'
  task :schema do
    destination = Html2rss::Config.schema_path

    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, "#{Html2rss::Config.json_schema_json}\n")

    puts "Generated config schema at #{destination}"
  end
end
