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
          module_function

          def index(_request)
            strategies = Html2rss::RequestService.strategy_names.map do |name|
              {
                id: name.to_s,
                name: name.to_s,
                display_name: name.to_s.split('_').map(&:capitalize).join(' '),
                description: strategy_description(name.to_s),
                available: true
              }
            end

            { success: true, data: { strategies: strategies }, meta: { total: strategies.count } }
          end

          def show(_request, strategy_id)
            available_strategies = Html2rss::RequestService.strategy_names

            raise NotFoundError, 'Strategy not found' unless available_strategies.include?(strategy_id)

            { success: true, data: { strategy: {
              id: strategy_id,
              name: strategy_id,
              display_name: strategy_id.split('_').map(&:capitalize).join(' '),
              description: strategy_description(strategy_id),
              available: true,
              default: strategy_id == 'ssrf_filter'
            } } }
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
