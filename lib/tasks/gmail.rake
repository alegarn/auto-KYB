namespace :gmail do
  desc "Generates the Google OAuth authorization URL to obtain a persistent refresh_token for system emails"
  task setup: :environment do
    credentials = Rails.application.credentials.google
    
    if credentials.blank? || credentials[:client_id].blank? || credentials[:client_secret].blank?
      puts "❌ Error: Google client_id and client_secret are missing from Rails credentials."
      exit 1
    end

    client_id = credentials[:client_id]
    client_secret = credentials[:client_secret]
    
    # We use a standard redirect_uri for testing / local generation
    redirect_uri = "http://localhost:3100/auth/google_oauth2/callback"
    
    auth_url = URI::HTTP.build(
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
    puts "3. Visit the following URL in your browser and authorize the application with the email address you want to send from:\n\n"
    
    puts "\e[36m#{auth_url}\e[0m"
    
    puts "\n4. After authorizing, you will be redirected to '#{redirect_uri}?code=4/0A...&...'."
    puts "5. Copy ONLY the 'code' parameter from the URL bar (everything between 'code=' and the next '&')."
    
    print "\nPaste the code here: "
    auth_code = STDIN.gets.chomp

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
    
    result = JSON.parse(response.body)

    if result["error"]
      puts "❌ Error exchanging code: #{result['error_description'] || result['error']}"
      exit 1
    end

    if result["refresh_token"]
      puts "\n✅ Success! Here is your refresh_token:\n\n"
      puts "\e[32m#{result['refresh_token']}\e[0m"
      puts "\nRun `bin/rails credentials:edit` and put it under `google:` next to your `client_id`!\n\n"
    else
      puts "\n⚠️ Notice: An access_token was generated, but NO fresh refresh_token was returned."
      puts "This usually happens if you've already authorized the app and did not use prompt=consent or revoked the old token."
      puts "Please visit your Google Account Security page, remove access to this app, and run this task again."
    end
  end
end