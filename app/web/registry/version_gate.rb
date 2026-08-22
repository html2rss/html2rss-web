# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Compares registry manifest versions for sync policy caps.
      module VersionGate
        module_function

        ##
        # @param manifest_version [String]
        # @param max_version [String, nil]
        # @return [Boolean] true when manifest_version is newer than max_version
        def exceeds_max?(manifest_version, max_version)
          return false if max_version.nil? || max_version.empty?

          compare(normalize(manifest_version), normalize(max_version)).positive?
        end

        ##
        # @param version [String]
        # @return [String]
        def normalize(version)
          version.to_s.delete_prefix('v')
        end

        ##
        # @param left [String]
        # @param right [String]
        # @return [Integer]
        def compare(left, right)
          Gem::Version.new(left) <=> Gem::Version.new(right)
        rescue ArgumentError
          left <=> right
        end
      end
    end
  end
end
