# frozen_string_literal: true

require 'uri'

require_relative '../../account_manager'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Builds the public metadata payload for the API root endpoint.
        module RootMetadata
          class << self
            # @param router [Roda::RodaRequest]
            # @return [Hash{Symbol=>Object}]
            def build(router)
              {
                api: {
                  name: 'html2rss-web API',
                  description: 'RESTful API for converting websites to RSS feeds',
                  openapi_url: "#{router.base_url}/api/v1/openapi.yaml"
                },
                demo: demo_payload
              }
            end

            private

            # @return [Hash{Symbol=>Object}]
            def demo_payload
              account = AccountManager.get_account_by_username('demo')
              return { enabled: false, sources: [] } unless account

              {
                enabled: true,
                token: account[:token],
                strategy: 'ssrf_filter',
                sources: Array(account[:allowed_urls]).map.with_index do |url, index|
                  { id: demo_source_id(url, index), url: url }
                end
              }
            end

            # @param url [String]
            # @param index [Integer]
            # @return [String]
            def demo_source_id(url, index)
              parts = demo_source_parts(url)
              return parts.join('-').gsub(/[^a-zA-Z0-9]+/, '-').downcase if parts.any?

              fallback_demo_source_id(index)
            rescue URI::InvalidURIError
              fallback_demo_source_id(index)
            end

            # @param url [String]
            # @return [Array<String>]
            def demo_source_parts(url)
              uri = URI.parse(url)
              [uri.host.to_s.gsub(/^www\./, ''), first_path_segment(uri)].reject(&:empty?)
            end

            # @param uri [URI::Generic]
            # @return [String]
            def first_path_segment(uri)
              uri.path.to_s.split('/').find { |segment| !segment.empty? }.to_s
            end

            # @param index [Integer]
            # @return [String]
            def fallback_demo_source_id(index)
              "demo-#{index + 1}"
            end
          end
        end
      end
    end
  end
end
