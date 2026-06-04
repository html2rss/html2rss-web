require_relative "lib/brotli/version"

Gem::Specification.new do |spec|
  spec.name          = "brotli"
  spec.version       = Brotli::VERSION
  spec.authors       = ["miyucy"]
  spec.email         = ["fistfvck@gmail.com"]

  spec.summary       = "Brotli compressor/decompressor"
  spec.description   = "Brotli compressor/decompressor"
  spec.homepage      = "https://github.com/miyucy/brotli"
  spec.license       = "MIT"

  tracked_files = Dir.chdir(__dir__) { `git ls-files -z`.split("\x0") }
  vendored_brotli_files = Dir.chdir(__dir__) do
    Dir["vendor/brotli/c/{common,enc,dec,include}/**/*"].select { |path| File.file?(path) }
  end

  spec.files = tracked_files
               .reject { |path| path == "vendor/brotli" || path.start_with?("test/") }
               .concat(vendored_brotli_files)
               .append("vendor/brotli/LICENSE")
               .sort
               .uniq
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/brotli/extconf.rb"]
end
