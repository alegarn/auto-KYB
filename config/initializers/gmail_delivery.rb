require "gmail_delivery"

ActionMailer::Base.add_delivery_method :gmail, GmailDelivery