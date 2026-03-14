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
          Thread.current[:request_context] = context
        end

        # @return [Context, nil]
        def current
          Thread.current[:request_context]
        end

        # @return [Hash{Symbol=>Object}]
        def current_h
          context = current
          return {} unless context

          context_hash(context).compact
        end

        # @return [nil]
        def clear!
          Thread.current[:request_context] = nil
          nil
        end

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
