# frozen_string_literal: true

require 'uri'

module Html2rss
  module Web
    module Registry
      ##
      # Enforces optional channel URL domain allowlists for registry bundles.
      module ScrapePolicy
        module_function

        ##
        # @param entry [Entry]
        # @param bundle [Index::RegistryBundle]
        # @return [void]
        # @raise [Errors::LoadError] when a config channel URL violates the allowlist
        def enforce!(entry, bundle) # rubocop:disable Metrics/CyclomaticComplexity
          allowed = entry.allowed_channel_domains
          return if allowed.nil? || allowed.empty?

          bundle.configs.each do |feed_id, config|
            channel_url = config.dig(:channel, :url)
            host = host_for(channel_url)
            next if host && allowed.any? { |domain| domain_allowed?(host, domain) }

            raise Errors::LoadError,
                  "Registry '#{entry.id}' config '#{feed_id}' channel.url host " \
                  "'#{host || channel_url}' is not allowed by allowed_channel_domains"
          end
        end

        ##
        # @param host [String]
        # @param allowed_domain [String]
        # @return [Boolean]
        def domain_allowed?(host, allowed_domain)
          normalized_host = host.downcase
          normalized_domain = allowed_domain.downcase
          normalized_host == normalized_domain || normalized_host.end_with?(".#{normalized_domain}")
        end

        ##
        # @param channel_url [String, nil]
        # @return [String, nil]
        def host_for(channel_url)
          return nil if channel_url.to_s.strip.empty?

          URI.parse(channel_url).host
        rescue URI::InvalidURIError
          nil
        end

        private_class_method :host_for
      end
    end
  end
end
