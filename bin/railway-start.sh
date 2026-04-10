#!/bin/bash
set -e

# Railway mounts the volume root as /rails/storage. Keep that root untouched and
# use an app-owned subdirectory for Active Storage files.
storage_root="${ACTIVE_STORAGE_ROOT:-${RAILWAY_VOLUME_MOUNT_PATH:-/rails/storage}/active_storage}"
export ACTIVE_STORAGE_ROOT="$storage_root"
mkdir -p "$ACTIVE_STORAGE_ROOT"

# Run database migrations/preparation
echo "Running database preparation..."
bundle exec rails db:prepare

# Start the Rails server via Thruster, enabling the Solid Queue Puma plugin
echo "Starting Rails server with Puma and Solid Queue plugin..."
export SOLID_QUEUE_IN_PUMA="true"
exec ./bin/thrust ./bin/rails server
