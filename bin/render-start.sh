#!/usr/bin/env bash

set -euo pipefail

jobs_pid=""
web_pid=""

cleanup() {
  if [[ -n "$jobs_pid" ]]; then
    kill "$jobs_pid" 2>/dev/null || true
  fi

  if [[ -n "$web_pid" ]]; then
    kill "$web_pid" 2>/dev/null || true
  fi

  wait 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# Render disks are isolated per service, so local Active Storage needs the queue
# process to run on the same instance as the web process for temporary deployments.
if [[ "${RUN_SOLID_QUEUE_IN_WEB:-1}" == "1" ]]; then
  ./bin/jobs start &
  jobs_pid=$!
fi

bundle exec thruster ./bin/rails server &
web_pid=$!

if [[ -n "$jobs_pid" ]]; then
  wait -n "$jobs_pid" "$web_pid"
  status=$?
else
  wait "$web_pid"
  status=$?
fi

exit "$status"