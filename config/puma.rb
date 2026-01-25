# frozen_string_literal: true

# Single worker in dev enables code reloading (cluster mode prevents reloading)
if ENV['RACK_ENV'] == 'development'
  workers 0
  threads_count = Integer(ENV.fetch('WEB_MAX_THREADS', 5))
  threads threads_count, threads_count
  plugin :tmp_restart
  log_requests true
else
  workers Integer(ENV.fetch('WEB_CONCURRENCY', 2))
  threads_count = Integer(ENV.fetch('WEB_MAX_THREADS', 5))
  threads threads_count, threads_count
  preload_app!
  log_requests false
end

port        ENV.fetch('PORT', 3000)
environment ENV.fetch('RACK_ENV', 'development')
