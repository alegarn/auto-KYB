# Gmail Delivery In Production

## Immediate Failure Mode

If production logs show:

```text
GmailDelivery: Failed to get access token - invalid_grant: Token has been expired or revoked.
```

the app is successfully reaching Google's OAuth token endpoint, but the configured refresh token is no longer valid.

## Code Paths Involved

- `lib/gmail_delivery.rb`
  Exchanges the stored refresh token for an access token and sends the message through the Gmail API.
- `lib/tasks/gmail.rake`
  Generates a new refresh token and can verify whether the configured token is still valid.
- `config/environments/production.rb`
  Uses the custom `:gmail` ActionMailer delivery method in production.
- `config/initializers/omniauth.rb`
  Handles sign-in OAuth. Gmail delivery now prefers its own credential namespace so mail sending can be managed independently from user login.

## Most Likely External Causes

- **The Google OAuth app is in `Testing` mode.** (Currently the most common issue).
  **Google officially enforces a 7-day expiration on all refresh tokens for apps in "Testing" status.** After 7 days, the token is systematically revoked and will throw `invalid_grant`.
- The stored refresh token was revoked manually by the mailbox owner.
- A new authorization flow generated a newer refresh token and Google invalidated the old one.
- The sender mailbox password or security posture changed and Google revoked the grant.
- The OAuth client used to mint the refresh token no longer matches the configured client credentials.

## Supported Credential Sources

Preferred:

```yaml
gmail_delivery:
  client_id: ...
  client_secret: ...
  refresh_token: ...
  redirect_uri: ... # optional
```

Fallbacks still supported for backward compatibility:

- `google.client_id`
- `google.client_secret`
- `google.refresh_token`
- `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN`
- legacy `GOOGLE_*` env vars

If any `gmail_delivery` value is present, the app treats that namespace as authoritative and does not mix missing fields back in from the legacy `google` namespace. This avoids half-migrated credentials producing hard-to-debug `invalid_grant` failures.

Within a namespace, the matching environment variables override encrypted credentials. This gives operators a fast emergency rotation path without editing credentials first.

## How To Repair Production

1. Ensure the Google Cloud OAuth consent screen is `Production` or `Internal`.
2. Ensure the configured redirect URI is allowed in Google Cloud.
3. Generate a new refresh token:

```bash
bin/rails gmail:setup
```

Run `gmail:setup` from a trusted local operator shell. The task prints the fresh refresh token to stdout exactly once.

4. Store the returned token in `gmail_delivery.refresh_token` or `GMAIL_REFRESH_TOKEN`.
5. Verify the secret before deploying:

```bash
bin/rails gmail:verify
```

The verify task performs a fresh refresh-token exchange. It does not trust a cached access token.

## Redirect URI Resolution

The setup task resolves the redirect URI in this order:

1. `GMAIL_OAUTH_REDIRECT_URI`
2. `gmail_delivery.redirect_uri`
3. `APP_BASE_URL + /auth/google_oauth2/callback`
4. `app.base_url + /auth/google_oauth2/callback`
5. `http://localhost:3100/auth/google_oauth2/callback` in development and test only

Outside local environments, missing redirect configuration is treated as an error so production recovery does not silently fall back to localhost.
Outside localhost, the resolved redirect URI must use HTTPS.