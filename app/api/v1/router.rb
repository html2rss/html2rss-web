# frozen_string_literal: true

require 'json'
require_relative 'feeds'
require_relative 'strategies'
require_relative 'health'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # RESTful API v1 router
        # Handles all v1 API routes with proper HTTP methods and status codes
        module Router
          module_function

          ##
          # Route API v1 requests
          # @param router [Roda::Request] Roda router object
          def route(router)

            # Health endpoints
            router.on 'health' do
              router.get 'ready' do
                response = Health.ready(router)
                router.response.status = 200
                router.response['Content-Type'] = 'application/json'
                JSON.generate(response)
              end

              router.get 'live' do
                response = Health.live(router)
                router.response.status = 200
                router.response['Content-Type'] = 'application/json'
                JSON.generate(response)
              end

              router.get do
                response = Health.show(router)
                status = response[:success] ? 200 : response.dig(:error, :status) || 500
                router.response.status = status
                router.response['Content-Type'] = 'application/json'
                JSON.generate(response)
              end
            end

            # Strategies resource
            router.on 'strategies' do
              router.get String do |strategy_id|
                response = Strategies.show(router, strategy_id)
                status = response[:success] ? 200 : response.dig(:error, :status) || 404
                router.response.status = status
                router.response['Content-Type'] = 'application/json'
                router.response['Cache-Control'] = 'public, max-age=3600'
                JSON.generate(response)
              end

              router.get do
                response = Strategies.index(router)
                router.response.status = 200
                router.response['Content-Type'] = 'application/json'
                router.response['Cache-Control'] = 'public, max-age=3600'
                JSON.generate(response)
              end
            end

            # Feeds resource
            router.on 'feeds' do
              router.get String do |feed_id|
                response = Feeds.show(router, feed_id)

                if response.is_a?(Hash) && response[:success]
                  router.response.status = 200
                  router.response['Content-Type'] = 'application/json'
                  JSON.generate(response)
                else
                  # This is XML content for RSS feeds
                  router.response.status = 200
                  response
                end
              end

              router.get do
                response = Feeds.index(router)
                router.response.status = 200
                router.response['Content-Type'] = 'application/json'
                router.response['Cache-Control'] = 'public, max-age=300'
                JSON.generate(response)
              end

              router.post do
                response = Feeds.create(router)
                status = response[:success] ? 201 : response.dig(:error, :status) || 400
                router.response.status = status
                router.response['Content-Type'] = 'application/json'
                JSON.generate(response)
              end

            end

            # API documentation endpoint
            router.get 'docs' do
              router.response['Content-Type'] = 'text/yaml'
              router.response['Cache-Control'] = 'public, max-age=3600'

              docs_path = File.join(__dir__, '../../../docs/api/v1/openapi.yaml')
              if File.exist?(docs_path)
                File.read(docs_path)
              else
                router.response.status = 404
                'Documentation not found'
              end
            end

            # API info endpoint
            router.get do
              response = {
                success: true,
                data: {
                  api: {
                    version: '1.0.0',
                    name: 'html2rss-web API',
                    description: 'RESTful API for converting websites to RSS feeds',
                    documentation: '/api/v1/docs',
                    endpoints: {
                      feeds: '/api/v1/feeds',
                      strategies: '/api/v1/strategies',
                      health: '/api/v1/health'
                    }
                  }
                },
                meta: {
                  timestamp: Time.now.iso8601,
                  version: '1.0.0'
                }
              }
              router.response.status = 200
              router.response['Content-Type'] = 'application/json'
              router.response['Cache-Control'] = 'public, max-age=3600'
              JSON.generate(response)
            end
          end
        end
      end
    end
  end
end
