# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module ApiV1
        class << self
          def call(router)
            router.on 'api', 'v1' do
              router.response['Content-Type'] = 'application/json'

              mount_health(router)
              mount_strategies(router)
              mount_feeds(router)
              mount_root(router)
            end
          end

          private

          def mount_health(router)
            router.on 'health' do
              router.get do
                JSON.generate(Api::V1::Health.show(router))
              end
            end
          end

          def mount_strategies(router)
            router.on 'strategies' do
              router.get do
                JSON.generate(Api::V1::Strategies.index(router))
              end
            end
          end

          def mount_feeds(router)
            router.on 'feeds' do
              router.get String do |token|
                result = Api::V1::Feeds.show(router, token)
                result.is_a?(Hash) ? JSON.generate(result) : result
              end

              router.post do
                JSON.generate(Api::V1::Feeds.create(router))
              end
            end
          end

          def mount_root(router)
            router.get do
              JSON.generate(success: true,
                            data: {
                              api: {
                                name: 'html2rss-web API',
                                description: 'RESTful API for converting websites to RSS feeds'
                              }
                            })
            end
          end
        end
      end
    end
  end
end
