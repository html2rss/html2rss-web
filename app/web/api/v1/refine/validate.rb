# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module Refine
          ##
          # Server-authoritative selectors check: the gem validation report plus exportable YAML.
          module Validate
            # Stands in for the channel URL when the caller sent no page URL.
            PLACEHOLDER_URL = 'https://example.com/'
            private_constant :PLACEHOLDER_URL

            class << self
              # @param request [Rack::Request]
              # @return [Hash{Symbol=>Object}] API success payload
              def call(request)
                account = Access.ensure_allowed!(request)
                body = JsonBody.object(request)
                url = Access.page_url(body['url'], account)
                raw = body.fetch('selectors') { raise BadRequestError, 'selectors is required' }
                report, selectors = assess(raw, url)

                Response.success(response: request.response,
                                 data: { report: report.to_h, selectors:, yaml: export_yaml(selectors, url) })
              end

              private

              # A schema failure is a reportable outcome; a malformed or oversized document stays a 400.
              #
              # @param raw [Object]
              # @param url [String, nil]
              # @return [Array(Html2rss::Config::ValidationReport, Hash, nil)]
              def assess(raw, url)
                selectors = SelectorsDocument.parse(raw)
                channel = { url: url || PLACEHOLDER_URL }
                report = Html2rss::Config.validate({ channel:, selectors: selectors || {} })
                [report, selectors]
              rescue SelectorsDocument::SchemaInvalid => error
                [error.report, nil]
              end

              # @param selectors [Hash, nil]
              # @param url [String, nil]
              # @return [String, nil]
              def export_yaml(selectors, url)
                return unless selectors

                Html2rss::Config.to_yaml(url ? { channel: { url: }, selectors: } : { selectors: })
              end
            end
          end
        end
      end
    end
  end
end
