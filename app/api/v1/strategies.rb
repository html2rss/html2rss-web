# frozen_string_literal: true

require_relative '../../exceptions'
require_relative '../../../helpers/api_response_helpers'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # RESTful API v1 for strategies resource
        # Handles listing available extraction strategies
        module Strategies
          module_function

          ##
          # List all available strategies
          # GET /api/v1/strategies
          # @param request [Roda::Request] request object
          # @return [Hash] JSON response with strategies list
          def index(request)
            strategies = Html2rss::RequestService.strategy_names.map do |name|
              {
                id: name.to_s,
                name: name.to_s,
                display_name: name.to_s.split('_').map(&:capitalize).join(' '),
                description: strategy_description(name.to_s),
                available: true
              }
            end

            ApiResponseHelpers.success_response(
              { strategies: strategies },
              { total: strategies.count }
            )
          end

          ##
          # Get a specific strategy
          # GET /api/v1/strategies/{id}
          # @param request [Roda::Request] request object
          # @param strategy_id [String] strategy identifier
          # @return [Hash] JSON response with strategy details
          def show(request, strategy_id)
            available_strategies = Html2rss::RequestService.strategy_names

            raise NotFoundError, 'Strategy not found' unless available_strategies.include?(strategy_id)

            ApiResponseHelpers.success_response({
                                                  strategy: {
                                                    id: strategy_id,
                                                    name: strategy_id,
                                                    display_name: strategy_id.split('_').map(&:capitalize).join(' '),
                                                    description: strategy_description(strategy_id),
                                                    available: true,
                                                    default: strategy_id == 'ssrf_filter'
                                                  }
                                                })
          end

          def strategy_description(strategy_name)
            descriptions = {
              'ssrf_filter' => 'Secure strategy with SSRF protection and content filtering',
              'faraday' => 'Standard HTTP client strategy (disabled for security)',
              'mechanize' => 'Browser automation strategy for JavaScript-heavy sites',
              'selenium' => 'Selenium WebDriver strategy for complex interactions'
            }

            descriptions[strategy_name] || 'Custom extraction strategy'
          end
        end
      end
    end
  end
end
