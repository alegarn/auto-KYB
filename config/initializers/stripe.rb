# frozen_string_literal: true

# Stripe initializer
# Configures the Stripe client with the secret key from the environment.
# - Uses ENV['STRIPE_SECRET_KEY'] to set Stripe.api_key
# - In development/test it will set the key if present and log a warning if missing
# - In production it will raise during boot if the secret is missing to avoid silent misconfiguration

# Ensure the Stripe gem is available (Bundler will normally require gems for Rails apps)
require "stripe"

stripe_key = ENV["STRIPE_SECRET_KEY"]

if Rails.env.production?
  if stripe_key.blank?
    Rails.logger.fatal("[Stripe] STRIPE_SECRET_KEY is not set in production. Application requires this to process payments.")
    # Fail fast in production so misconfiguration is detected immediately on deploy
    raise "Missing STRIPE_SECRET_KEY environment variable in production"
  end
else
  unless stripe_key.present?
    Rails.logger.warn("[Stripe] STRIPE_SECRET_KEY is not set. Stripe API calls will fail until configured. Set STRIPE_SECRET_KEY in your .env or environment.")
  end
end

# Configure the Stripe client
Stripe.api_key = stripe_key

# Optional: set API version or other global Stripe settings here, e.g. Stripe.api_version = "2023-08-16"

# Developers: for local development use dotenv-rails (.env) or set ENV vars in your shell.
# In production, prefer using secure environment variable management or Rails encrypted credentials.
