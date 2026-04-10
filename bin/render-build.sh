#!/usr/bin/env bash

set -euo pipefail

bundle install
npm ci
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:migrate