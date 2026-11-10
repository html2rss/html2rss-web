# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module Refine
          ##
          # Reuses fetched pages while a person iterates on selectors for one page.
          #
          # Installs a scoped {Html2rss::RequestService::ResponseCache}: only fetches made inside {.within} are
          # cached, so serving feeds and every other request keep fetching live. Callers must have passed the
          # URL access checks before entering the scope.
          module PageCache
            TTL_SECONDS = 300
            MAX_ENTRIES = 32
            SCOPE = :refine_page_cache

            ##
            # Delegates to the shared cache inside {PageCache.within}, and fetches live everywhere else.
            class Scoped
              # @param cache [#fetch] cache that stores initial 2xx responses
              def initialize(cache)
                @cache = cache
              end

              # @param key [Object] cache key chosen by the gem
              # @yieldreturn [Html2rss::RequestService::Response] the live response
              # @return [Html2rss::RequestService::Response]
              def fetch(key, &)
                Fiber[SCOPE] ? @cache.fetch(key, &) : yield
              end
            end

            class << self
              # @yield the block whose page fetches may be served from cache
              # @return [Object] the block's value
              def within
                install
                previous = Fiber[SCOPE]
                Fiber[SCOPE] = true
                yield
              ensure
                Fiber[SCOPE] = previous
              end

              private

              # @return [void]
              def install
                return if Html2rss::RequestService.response_cache.is_a?(Scoped)

                cache = Html2rss::RequestService::ResponseCache.new(ttl: TTL_SECONDS, max_entries: MAX_ENTRIES)
                Html2rss::RequestService.response_cache = Scoped.new(cache)
              end
            end
          end
        end
      end
    end
  end
end
