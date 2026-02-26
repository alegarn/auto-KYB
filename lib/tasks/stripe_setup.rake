# frozen_string_literal: true
=begin 
namespace :stripe_setup do
  desc "Create Basic Plan product and monthly price in Stripe and print the price ID"
  task create_basic_plan: :environment do
    require "stripe"

    if ENV["STRIPE_SECRET_KEY"].to_s.strip.empty?
      warn "[Stripe] STRIPE_SECRET_KEY is not set. Set it before running this task."
    end

    begin
      # Find existing product named "Basic Plan"
      products = Stripe::Product.list(limit: 100)
      product = products.data.find { |p| p.name == "Basic Plan" }

      unless product
        product = Stripe::Product.create(
          name: "Basic Plan",
          description: "Basic monthly subscription plan"
        )
        puts "[Stripe] Created product #{product.id} (Basic Plan)"
      else
        puts "[Stripe] Found existing product #{product.id} (Basic Plan)"
      end

      # Look for existing monthly price ($10/month => 1000 cents)
      prices = Stripe::Price.list(product: product.id, limit: 100)
      monthly_price = prices.data.find do |pr|
        pr.recurring && pr.recurring.interval == "month" &&
          pr.unit_amount == 1000 && pr.currency == "usd"
      end

      unless monthly_price
        monthly_price = Stripe::Price.create(
          product: product.id,
          unit_amount: 1000,
          currency: "usd",
          recurring: { interval: "month" },
          nickname: "Basic Plan - Monthly"
        )
        puts "[Stripe] Created price #{monthly_price.id} for product #{product.id} ($10/month)"
      else
        puts "[Stripe] Found existing price #{monthly_price.id} for product #{product.id} ($10/month)"
      end

      puts
      puts "Set the price id in your environment:"
      puts "  export STRIPE_BASIC_PLAN_PRICE_ID=#{monthly_price.id}"
      puts "Or add to your .env / credentials as STRIPE_BASIC_PLAN_PRICE_ID=#{monthly_price.id}"
    rescue Stripe::StripeError => e
      warn "[Stripe] API error: #{e.message}"
      exit 1
    rescue => e
      warn "[Stripe] Unexpected error: #{e.class} - #{e.message}"
      exit 1
    end
  end
end
=end