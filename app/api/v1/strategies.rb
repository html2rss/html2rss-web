# frozen_string_literal: true

require_relative '../../exceptions'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # RESTful API v1 for strategies resource
        # Handles listing available extraction strategies
        module Strategies
          class << self
            def index(_request)
              strategies = Html2rss::RequestService.strategy_names.map do |name|
                {
                  id: name.to_s,
                  name: name.to_s,
                  display_name: name.to_s.split('_').map(&:capitalize).join(' ')
                }
              end

              { success: true, data: { strategies: strategies }, meta: { total: strategies.count } }
            end
          end
        end
      end
    end
  end
end
