#!/usr/bin/env sh
set -e

php artisan optimize

# Start Laravel Octane with FrankenPHP
export PORT="${PORT:-8080}"
export ADMIN_PORT="${ADMIN_PORT:-2019}"
export OCTANE_WORKERS="${OCTANE_WORKERS:-auto}"
export OCTANE_MAX_REQUESTS="${OCTANE_MAX_REQUESTS:-500}"
export OCTANE_MAX_EXECUTION_TIME="${OCTANE_MAX_EXECUTION_TIME:-30}"

exec php -d variables_order=EGPCS artisan octane:start \
  --server=frankenphp \
  --host=0.0.0.0 \
  --port="$PORT" \
  --admin-port="$ADMIN_PORT" \
  --workers="$OCTANE_WORKERS" \
  --max-requests="$OCTANE_MAX_REQUESTS" \
  --max-execution-time="$OCTANE_MAX_EXECUTION_TIME"
