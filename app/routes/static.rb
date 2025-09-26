# frozen_string_literal: true

module Html2rss
  module Web
    module Routes
      module Static
        class << self
          def call(router, feed_handler:, index_renderer:)
            router.get String do |feed_name|
              next if feed_name.include?('.') && !feed_name.end_with?('.xml', '.rss')

              feed_handler.call(router, feed_name)
            end

            router.root do
              index_renderer.call(router)
            end
          end
        end
      end
    end
  end
end
