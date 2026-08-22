# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Trust mode and verification keys passed to {Html2rss::Registry::Bundle.load}.
      TrustContext = Data.define(:mode, :public_keys) do
        ##
        # @param entry [Entry]
        # @param bundle_dir [String]
        # @return [TrustContext]
        def self.for_entry(entry, bundle_dir)
          case entry.mode
          in :path
            integrity_only
          in :sync
            signed_bundle?(bundle_dir, entry) ? signed(entry.public_keys) : integrity_only
          end
        end

        ##
        # @return [TrustContext]
        def self.integrity_only
          new(mode: :integrity_only, public_keys: {})
        end

        ##
        # @param public_keys [Hash{String => OpenSSL::PKey::PKey}]
        # @return [TrustContext]
        def self.signed(public_keys)
          new(mode: :signed, public_keys:)
        end

        ##
        # @return [Hash{Symbol => Object}] keyword args for {Html2rss::Registry::Bundle.load}
        def load_options
          { trust: mode, public_keys: }
        end

        ##
        # @param bundle_dir [String]
        # @param entry [Entry]
        # @return [Boolean]
        def self.signed_bundle?(bundle_dir, entry)
          signature_path = File.join(bundle_dir, Html2rss::Registry::Manifest::SIGNATURE_FILE)
          File.file?(signature_path) && !entry.public_keys.empty?
        end

        private_class_method :signed_bundle?
      end
    end
  end
end
