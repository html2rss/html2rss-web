# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module Refine
          ##
          # Ranked selector candidates derived from a live capture of the page.
          # Empty buckets are a successful response.
          module Suggest
            # Upper bound for the client-supplied items selector hint.
            MAX_HINT_LENGTH = 256
            BUCKETS = %i[items title link published].freeze

            class << self
              # @param request [Rack::Request]
              # @return [Hash{Symbol=>Object}] API success payload
              def call(request)
                account = Access.ensure_allowed!(request, live_fetch: true)
                body = JsonBody.object(request)
                url = Access.page_url!(body['url'], account)
                captured = Html2rss.capture(url, strategy: :auto, items_selector: hint(body['items_selector']))

                Response.success(response: request.response, data: {
                                   candidates: BUCKETS.to_h { [it, entries(captured.candidates[it])] },
                                   segment_strategy: captured.segment_strategy&.to_s,
                                   admission_drops: captured.admission_drops
                                 })
              end

              private

              # @param raw [Object]
              # @return [String, nil]
              def hint(raw)
                text = raw.to_s.strip
                raise BadRequestError, 'items_selector is too long' if text.length > MAX_HINT_LENGTH

                text unless text.empty?
              end

              # @param candidates [Array<Hash>, nil]
              # @return [Array<Hash{Symbol=>Object}>] selector, sample and, for items, enhance
              def entries(candidates)
                Array(candidates).map { it.slice(:selector, :sample, :enhance) }
              end
            end
          end
        end
      end
    end
  end
end
