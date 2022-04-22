# frozen_string_literal: true

workers Integer(ENV.fetch('WEB_CONCURRENCY', 2))
threads_count = Integer(ENV.fetch('WEB_MAX_THREADS', 5))
threads threads_count, threads_count

preload_app!

port        ENV.fetch('PORT', 3000)
environment ENV.fetch('RACK_ENV', 'development')
