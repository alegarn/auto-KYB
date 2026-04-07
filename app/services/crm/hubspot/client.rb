# frozen_string_literal: true

module Crm
  module Hubspot
    class Client

      attr_reader :connection

      def initialize(connection)
        @connection = connection
        ensure_valid_token!
      end

      # Returns a configured Hubspot::Client from the SDK
      def sdk
        @sdk ||= ::Hubspot::Client.new(access_token: connection.access_token)
      end

      # Convenience: CRM contacts API
      def contacts_api
        sdk.crm.contacts.basic_api
      end

      # Convenience: CRM companies API
      def companies_api
        sdk.crm.companies.basic_api
      end

      # Convenience: CRM contacts search API
      def contacts_search_api
        sdk.crm.contacts.search_api
      end

      # Convenience: CRM companies search API
      def companies_search_api
        sdk.crm.companies.search_api
      end

      # Convenience: generic API request (for endpoints not wrapped by SDK)
      def api_request(options)
        sdk.api_request(options)
      end

      # Executes a block with rate limit retries
      def with_rate_limit_retry(max_retries: 3, &block)
        retries = 0
        begin
          yield
        rescue ::Hubspot::ApiError => e
          if e.code == 429 && retries < max_retries
            retries += 1
            wait_time = (e.response_headers&.dig("Retry-After") || 10).to_i
            Rails.logger.warn("[HubSpot] Rate limited, retrying in #{wait_time}s (attempt #{retries}/#{max_retries})")
            sleep(wait_time)
            retry
          else
            raise
          end
        end
      end

      # Refreshes the token if expired or about to expire, then resets SDK
      def ensure_valid_token!
        return unless connection.token_expires_soon?

        oauth = Crm::Hubspot::OAuth.new(connection: connection)
        tokens = oauth.refresh_token(connection.refresh_token)

        connection.update!(
          access_token: tokens[:access_token],
          refresh_token: tokens[:refresh_token],
          expires_at: Time.current + tokens[:expires_in].to_i.seconds
        )

        # Reset the memoized SDK so it picks up the new token
        @sdk = nil
      end

    end
  end
end
