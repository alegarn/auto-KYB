#!/bin/bash
set -e

# Railway volumes are mounted to /rails/storage by default if configured
# Ensure the directory exists and is writable
mkdir -p /rails/storage

# Run database migrations/preparation
echo "Running database preparation..."
bundle exec rails db:prepare

# Start background jobs (Solid Queue) in the background if requested
if [ "$RUN_SOLID_QUEUE_IN_WEB" = "1" ]; then
  echo "Starting Solid Queue..."
  bundle exec ./bin/jobs &
fi

# Start the Rails server via Thruster
echo "Starting Rails server..."
exec ./bin/thrust ./bin/rails server
