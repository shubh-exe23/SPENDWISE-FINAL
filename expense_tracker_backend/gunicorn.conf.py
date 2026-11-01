import os
bind = '0.0.0.0:' + os.getenv('PORT', '8080')
# One process preserves the existing in-memory reset codes and one scheduler.
workers = 1
worker_class = 'gthread'
threads = 4
timeout = 120
graceful_timeout = 30
preload_app = False
accesslog = '-'
errorlog = '-'
