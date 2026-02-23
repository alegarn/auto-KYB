# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Optionally run Stripe setup from seeds. This is helpful in development to ensure a price id exists.
# The task will only be invoked if a Stripe secret key is present and STRIPE_BASIC_PLAN_PRICE_ID is not set.
if ENV["STRIPE_SECRET_KEY"].present? && ENV["STRIPE_BASIC_PLAN_PRICE_ID"].blank?
  puts "Running Stripe setup task to create Basic Plan and price..."
  begin
    require "rake"
    # Load rake tasks if not already loaded (Rails.application.load_tasks is safe to call repeatedly)
    Rails.application.load_tasks
    Rake::Task["stripe_setup:create_basic_plan"].invoke
  rescue => e
    warn "Failed to run Stripe setup task from seeds: #{e.class} - #{e.message}"
  end
else
  puts "Skipping Stripe setup from seeds (ensure STRIPE_BASIC_PLAN_PRICE_ID is set if you need an existing price)."
end
