# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Server-authoritative config check for the refinement studio.
        #
        # Parses YAML or a selectors object, gates it through {SelectorsDocument},
        # and returns the gem validation report plus normalized YAML.
        module ValidateConfig
          PLACEHOLDER_URL = 'https://example.com/'
          private_constant :PLACEHOLDER_URL

          class << self
            ##
            # @param request [Rack::Request]
            # @return [Hash{Symbol=>Object}]
            def call(request)
              account = StudioRequest.ensure_allowed!(request)
              body = StudioRequest.json_object(request)
              url = StudioRequest.page_url(body['url'], account)
              report, selectors = assess(body, url)
              Response.success(response: request.response, data: payload(report, selectors, url))
            end

            private

            # @param body [Hash]
            # @param url [String, nil]
            # @return [Array(Html2rss::Config::ValidationReport, Hash, nil)]
            def assess(body, url)
              reject_denied_body_keys!(body)
              return assess_yaml(body['yaml'], url) if body.key?('yaml') && !body['yaml'].nil?
              raise BadRequestError, 'yaml or selectors is required' unless body.key?('selectors')

              assess_fragment({ selectors: body['selectors'] }, url)
            end

            # Transport keys (`url`, `selectors`, `yaml`) stay; denied config roots do not.
            #
            # @param body [Hash]
            # @return [void]
            def reject_denied_body_keys!(body)
              denied = body.each_key.map { |key| key.to_s.to_sym }.find { SelectorsDocument::DENIED_ROOT_KEYS.include?(it) }
              raise BadRequestError, "#{denied} is not allowed" if denied
            end

            # @param yaml [Object]
            # @param url [String, nil]
            # @return [Array(Html2rss::Config::ValidationReport, Hash, nil)]
            def assess_yaml(yaml, url)
              assess_fragment(Html2rss::Config.from_yaml(yaml.to_s), url)
            rescue ArgumentError, Psych::Exception => error
              [Html2rss::Config::IssueMapper.parse_failure(error.message), nil]
            end

            # A schema failure is a reportable outcome; anything else the root key
            # gate rejects (denied or unknown root key, oversized wire) stays a 400.
            #
            # @param fragment [Hash]
            # @param url [String, nil]
            # @return [Array(Html2rss::Config::ValidationReport, Hash, nil)]
            def assess_fragment(fragment, url)
              document = SelectorsDocument.from_client(fragment)
              [validation_report(document.selectors, url), document.selectors]
            rescue SelectorsDocument::SchemaInvalid => error
              selectors = fragment.is_a?(Hash) ? fragment[:selectors] || fragment['selectors'] : nil
              [error.report, selectors.is_a?(Hash) ? selectors : nil]
            end

            # The gem validator needs a channel URL. The export uses the caller's
            # page URL and never the placeholder.
            #
            # @param selectors [Hash, nil]
            # @param url [String, nil]
            # @return [Html2rss::Config::ValidationReport]
            def validation_report(selectors, url)
              Html2rss::Config.validate({ channel: { url: url || PLACEHOLDER_URL }, selectors: selectors || {} })
            end

            # @param report [Html2rss::Config::ValidationReport]
            # @param selectors [Hash, nil]
            # @param url [String, nil]
            # @return [Hash{Symbol=>Object}]
            def payload(report, selectors, url)
              { report: report.to_h, selectors:, yaml: export_yaml(selectors, url) }
            end

            # @param selectors [Hash, nil]
            # @param url [String, nil]
            # @return [String, nil]
            def export_yaml(selectors, url)
              return unless selectors.is_a?(Hash)

              document = url ? { channel: { url: }, selectors: } : { selectors: }
              Html2rss::Config.to_yaml(document)
            end
          end
        end
      end
    end
  end
end
