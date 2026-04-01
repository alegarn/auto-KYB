source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# environment variable management for Rails [
gem "dotenv-rails", groups: [ :development, :test ]

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Amazon S3 for Active Storage file uploads (production)
gem "aws-sdk-s3", require: false

# Use Vite in Rails and bring joy to your JavaScript experience
gem "vite_rails", "~> 3.0"

# The Rails adapter for Inertia.js [https://inertia-rails.dev]
gem "inertia_rails", "~> 3.10"

# Authorization via policies [https://github.com/varvet/pundit]
gem "pundit"

# An authentication system generator for Rails applications
# we leave gem here to watch for security updates
gem "authentication-zero"
# Use OmniAuth to support multi-provider authentication [https://github.com/omniauth/omniauth]
gem "omniauth"
# Provides a mitigation against CVE-2015-9284 [https://github.com/cookpad/omniauth-rails_csrf_protection]
gem "omniauth-rails_csrf_protection"
gem "omniauth-google-oauth2"

# Brings Rails named routes to javascript
# $ rails generate js_routes:middleware
gem "js-routes"

# Rate limiting
gem "rack-attack"

# Support for PostgreSQL's pgcrypto extension
gem "pgcrypto"

# Pagination library
gem "pagy", "~> 9.3", ">= 9.3.4"

# CSV
gem "csv", "~> 3.0"

# Stripe API client
gem "stripe", "~> 18.3.0"


gem "oauth2", "~> 1.2"
gem "hubspot-api-client", "~> 20.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  # Static Ruby linter
  gem "rubocop", require: false
  gem "rubocop-rails", require: false

  # RSpec for Rails 7.2+
  gem "rspec-rails", "~> 8.0"

  # Fixtures replacement with a straightforward definition syntax
  gem "factory_bot_rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Use letter_opener to preview emails in the browser in development [https://github.com/ryanb/letter_opener]
  gem "letter_opener"

  # Debugging tool
  gem "pry", "~> 0.16.0"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  # Synchronize Capybara commands with application JavaScript and AJAX requests
  gem "capybara-lockstep"
  gem "selenium-webdriver"
end

gem "webmock", "~> 3.26", group: :test
