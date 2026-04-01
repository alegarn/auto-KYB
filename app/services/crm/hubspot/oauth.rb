# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Crm
  module Hubspot
    class OAuth
      TOKEN_URL     = "https://api.hubapi.com/oauth/v1/token"
      # Override via credentials hubspot.authorize_url for non-default data centres
      # e.g. hubspot: { authorize_url: "https://app-na2.hubspot.com/oauth/authorize" }
      AUTHORIZE_URL = "https://app.hubspot.com/oauth/authorize"

      def initialize(connection: nil)
        @connection = connection
      end

      # Step 1: Build authorization URL
      def authorize_url(state:)
        # HubSpot prefers %20 over + for URL encoding scopes
        scopes_encoded = HubspotConfig.scopes.split(" ").map { |s| CGI.escape(s) }.join("%20")

        params = {
          client_id:    HubspotConfig.client_id,
          redirect_uri: HubspotConfig.redirect_uri,
          state:        state
        }

        "#{HubspotConfig.authorize_url}?#{params.to_query}&scope=#{scopes_encoded}"
      end

      # Step 2: Exchange authorization code for tokens
      def exchange_code(code)
        response = post_token_request(
          grant_type:   "authorization_code",
          code:         code,
          redirect_uri: HubspotConfig.redirect_uri
        )
        parse_token_response(response)
      end

      # Step 3: Refresh expired access token
      def refresh_token(refresh_token)
        response = post_token_request(
          grant_type:    "refresh_token",
          refresh_token: refresh_token,
          redirect_uri:  HubspotConfig.redirect_uri
        )
        parse_token_response(response)
      end

      private

      def post_token_request(params)
        uri = URI(TOKEN_URL)
        body = {
          client_id:     HubspotConfig.client_id,
          client_secret: HubspotConfig.client_secret
        }.merge(params)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path)
        request.set_form_data(body)
        request["Content-Type"] = "application/x-www-form-urlencoded"

        http.request(request)
      end

      def parse_token_response(response)
        data = JSON.parse(response.body)

        if response.is_a?(Net::HTTPSuccess)
          {
            access_token:  data["access_token"],
            refresh_token: data["refresh_token"],
            expires_in:    data["expires_in"]  # seconds (typically 1800)
          }
        else
          raise OAuthError, "HubSpot OAuth failed: #{data['message'] || data}"
        end
      end
    end
  end
end

