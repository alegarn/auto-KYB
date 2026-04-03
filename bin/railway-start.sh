#!/bin/bash
set -e

# Railway volumes are mounted to /rails/storage by default if configured
# Ensure the directory exists and is writable
mkdir -p /rails/storage

# Run database migrations/preparation
echo "Running database preparation..."
bundle exec rails db:prepare

# Start the Rails server via Thruster, enabling the Solid Queue Puma plugin
echo "Starting Rails server with Puma and Solid Queue plugin..."
export SOLID_QUEUE_IN_PUMA="true"
exec ./bin/thrust ./bin/rails server
