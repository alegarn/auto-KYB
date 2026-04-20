namespace :gmail do
  desc "Generates the Google OAuth authorization URL to obtain a persistent refresh_token for system emails"
  task setup: :environment do
    credentials = GmailDelivery.delivery_credentials
    missing_keys = %i[client_id client_secret].select { |key| credentials[key].blank? }

    if missing_keys.any?
      puts "❌ Error: Missing Gmail delivery credentials: #{missing_keys.join(', ')}."
      puts "Configure `gmail_delivery.client_id` and `gmail_delivery.client_secret` in Rails credentials or set `GMAIL_CLIENT_ID` / `GMAIL_CLIENT_SECRET`."
      exit 1
    end

    client_id = credentials[:client_id]
    client_secret = credentials[:client_secret]

    redirect_uri = GmailDelivery.oauth_redirect_uri

    auth_url = URI::HTTPS.build(
      host: "accounts.google.com",
      path: "/o/oauth2/v2/auth",
      query: URI.encode_www_form({
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: "https://www.googleapis.com/auth/gmail.send",
        access_type: "offline", # Crucial to get a refresh_token
        prompt: "consent"       # Forces consent screen even if already authorized, ensuring refresh_token is sent
      })
    )

    puts "\n📧 Gmail API Setup: Obtaining your Refresh Token"
    puts "=" * 50
    puts "1. To send emails via Gmail API, we need a permanent refresh_token."
    puts "2. Please ensure your Google API Console has '#{redirect_uri}' configured as an Authorized Redirect URI."
    puts "3. If the Google OAuth app is External, move the consent screen publishing status to Production before using this in production. Gmail refresh tokens from a Testing app can expire quickly."
    puts "4. Visit the following URL in your browser and authorize the application with the email address you want to send from:\n\n"

    puts "\e[36m#{auth_url}\e[0m"

    puts "\n5. After authorizing, you will be redirected to '#{redirect_uri}?code=4/0A...&...'."
    puts "6. Copy ONLY the 'code' parameter from the URL bar (everything between 'code=' and the next '&')."

    print "\nPaste the code here: "
    auth_code = STDIN.gets&.chomp

    if auth_code.blank?
      puts "❌ Error: No authorization code was provided."
      exit 1
    end

    puts "\nExchanging code for tokens..."

    # Exchange code for tokens
    uri = URI("https://oauth2.googleapis.com/token")
    response = Net::HTTP.post_form(uri, {
      client_id: client_id,
      client_secret: client_secret,
      code: auth_code,
      redirect_uri: redirect_uri,
      grant_type: "authorization_code"
    })

    begin
      result = JSON.parse(response.body)
    rescue JSON::ParserError
      puts "❌ Error exchanging code: Unexpected response from Google."
      exit 1
    end

    if result["error"]
      puts "❌ Error exchanging code: #{result['error_description'] || result['error']}"
      exit 1
    end

    if result["refresh_token"]
      puts "\n✅ Success! Here is your refresh_token:\n\n"
      puts "\e[32m#{result['refresh_token']}\e[0m"
      puts "\nTreat this refresh_token as a secret. Do not generate or store it in a shared shell, recording, or support transcript."
      puts "\nStore it under `gmail_delivery.refresh_token` in Rails credentials or as `GMAIL_REFRESH_TOKEN`."
      puts "Legacy `google.refresh_token` still works as a fallback, but dedicated `gmail_delivery` keys are now preferred.\n\n"
    else
      puts "\n⚠️ Notice: An access_token was generated, but NO fresh refresh_token was returned."
      puts "This usually happens if you've already authorized the app and did not use prompt=consent or revoked the old token."
      puts "Please visit your Google Account Security page, remove access to this app, and run this task again."
    end
  rescue ArgumentError => e
    puts "❌ #{e.message}"
    exit 1
  end

  desc "Verifies that the configured Gmail delivery refresh token can be exchanged for an access token"
  task verify: :environment do
    credentials = GmailDelivery.delivery_credentials
    missing_keys = GmailDelivery.missing_credential_keys(credentials)

    if missing_keys.any?
      puts "❌ Error: Missing Gmail delivery credentials: #{missing_keys.join(', ')}."
      puts "Expected `gmail_delivery.client_id`, `gmail_delivery.client_secret`, and `gmail_delivery.refresh_token` (or the equivalent `GMAIL_*` env vars)."
      exit 1
    end

    GmailDelivery.new.verify!
    puts "✅ Gmail delivery refresh token is valid."
  rescue GmailDelivery::InvalidRefreshTokenError => e
    puts "❌ #{e.message}"
    puts "Run `bin/rails gmail:setup`, authorize again, and store the new token under `gmail_delivery.refresh_token`."
    puts "Also verify that the Google OAuth consent screen is Production/Internal and that app access has not been revoked for the sender mailbox."

    exit 1
  rescue StandardError => e
    puts "❌ #{e.message}"

    exit 1
  end
end
