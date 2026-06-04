# -*- encoding: utf-8 -*-
# stub: html2rss 0.19.1 ruby lib

Gem::Specification.new do |s|
  s.name = "html2rss".freeze
  s.version = "0.19.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "changelog_uri" => "https://github.com/html2rss/html2rss/releases/tag/v0.19.1", "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Gil Desmarais".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.description = "Supports JSON content, custom HTTP headers, and post-processing of extracted content.".freeze
  s.email = ["html2rss@desmarais.de".freeze]
  s.executables = ["html2rss".freeze]
  s.files = ["exe/html2rss".freeze]
  s.homepage = "https://github.com/html2rss/html2rss".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "4.0.6".freeze
  s.summary = "Generates RSS feeds from websites by scraping a URL and using CSS selectors to extract item.".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<addressable>.freeze, ["~> 2.7".freeze])
  s.add_runtime_dependency(%q<brotli>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<dry-validation>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<faraday>.freeze, ["> 2.0.1".freeze, "< 3.0".freeze])
  s.add_runtime_dependency(%q<faraday-follow_redirects>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<faraday-gzip>.freeze, ["~> 3".freeze])
  s.add_runtime_dependency(%q<kramdown>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<mime-types>.freeze, ["> 3.0".freeze])
  s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 1.10".freeze, "< 2.0".freeze])
  s.add_runtime_dependency(%q<parallel>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<puppeteer-ruby>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<regexp_parser>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<reverse_markdown>.freeze, ["~> 3.0".freeze])
  s.add_runtime_dependency(%q<rss>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<sanitize>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<thor>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<tzinfo>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<zeitwerk>.freeze, [">= 0".freeze])
end
