# -*- encoding: utf-8 -*-
# stub: faraday-gzip 3.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "faraday-gzip".freeze
  s.version = "3.1.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/bodrovis/faraday-gzip/issues", "changelog_uri" => "https://github.com/bodrovis/faraday-gzip/blob/master/CHANGELOG.md", "documentation_uri" => "http://www.rubydoc.info/gems/faraday-gzip/3.1.0", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/bodrovis/faraday-gzip" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ilya Krukowski".freeze]
  s.date = "1980-01-02"
  s.description = "Faraday plugin to automatically set compression headers (GZip, Deflate, Brotli) and decompress the response.\n".freeze
  s.email = ["golosizpru@gmail.com".freeze]
  s.homepage = "https://github.com/bodrovis/faraday-gzip".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0".freeze)
  s.rubygems_version = "4.0.3".freeze
  s.summary = "Automatically sets compression headers and decompresses the response".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<faraday>.freeze, [">= 2.0".freeze, "< 3".freeze])
  s.add_runtime_dependency(%q<zlib>.freeze, ["~> 3.0".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.22".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.82".freeze])
  s.add_development_dependency(%q<rubocop-performance>.freeze, ["~> 1.26".freeze])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 3.8".freeze])
end
