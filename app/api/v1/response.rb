# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module Response
          class << self
            def success(data:, meta: nil, response: nil, status: 200)
              response['Content-Type'] = 'application/json' if response
              response.status = status if response

              payload = { success: true, data: data }
              payload[:meta] = meta if meta
              payload
            end
          end
        end
      end
    end
  end
end
