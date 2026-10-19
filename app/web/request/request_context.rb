# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Request-scoped context accessors for observability correlation.
    module RequestContext
      ##
      # Immutable request context model.
      Context = Data.define(:request_id, :path, :http_method, :route_group, :actor, :strategy, :started_at)

      class << self
        # @param context [Context]
        # @return [Context]
        def set!(context)
          Fiber[:request_context] = context
        end

        # @return [Context, nil]
        def current = Fiber[:request_context]

        # @return [Hash{Symbol=>Object}]
        def current_h = current&.then { context_hash(it).compact } || {}

        # @return [nil]
        def clear! = Fiber[:request_context] = nil

        # @param context [Context]
        # @return [Hash{Symbol=>Object}]
        def context_hash(context)
          {
            request_id: context.request_id,
            path: context.path,
            method: context.http_method,
            route_group: context.route_group,
            actor: context.actor,
            strategy: context.strategy,
            started_at: context.started_at
          }
        end
      end
    end
  end
end
