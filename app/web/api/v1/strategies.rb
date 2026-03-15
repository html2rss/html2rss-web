# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Strategy metadata endpoints for API v1.
        #
        # Exposes only lightweight strategy metadata so clients can render
        # choices without coupling to backend strategy internals.
        module Strategies
          class << self
            # @param _request [Rack::Request]
            # @return [Hash{Symbol=>Object}] response with strategy list.
            # @option return [Hash] :data strategies payload.
            # @option return [Array<Hash>] :strategies available strategy metadata.
            # @option return [Hash] :meta list metadata.
            # @option return [Integer] :total number of strategies.
            def index(_request)
              strategies = Html2rss::RequestService.strategy_names.map do |name|
                {
                  id: name.to_s,
                  name: name.to_s,
                  display_name: display_name_for(name)
                }
              end

              Response.success(data: { strategies: strategies }, meta: { total: strategies.count })
            end

            private

            def display_name_for(name)
              case name.to_s
              when 'ssrf_filter' then 'Standard (recommended)'
              when 'browserless' then 'JavaScript pages'
              else name.to_s.split('_').map(&:capitalize).join(' ')
              end
            end
          end
        end
      end
    end
  end
end
