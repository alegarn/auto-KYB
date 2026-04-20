# Authentication & Authorization Specification

This document outlines the end-to-end authentication and authorization flow for the application, specifically focusing on the integration between Stripe subscriptions and user identity management.

## Overview

The application follows a **"Pay First"** signup model. Users are not granted access until a valid subscription is established via Stripe. Identity is tied to a unique Stripe Customer ID.

## 1. Subscription & Signup Flow (The "Pay First" Path)

### Workflow
1. **Selection**: User visits the `/sign_up` page and selects a subscription plan from the Stripe Pricing Table.
2. **Payment**: User is redirected to a Stripe Checkout Session.
3. **Verification**: After successful payment, Stripe redirects the user back to the application.
4. **User Creation**:
    - The `checkout.session.completed` webhook or the redirect to `/registrations/complete` triggers user creation.
    - The system extracts the `stripe_customer_id`, `email`, and `subscription_id`.
    - A `User` record is created (or updated if it already exists for that email/stripe_customer_id).
    - The `User` is marked as `verified: true` and `subscription_status: 'active'`.

### Welcome Email
Immediately upon user creation/activation, a **Welcome Email** is dispatched.
- **Purpose**: To provide the user with their first entry point into the application and acknowledge their subscription.
- **Identity Links**: The email contains two secure links:
    1. **Magic Link**: A short-lived (10 min) sign-in token.
    2. **Recovery Link**: A long-lived (7 day) recovery token cryptographically tied to the user's `stripe_customer_id`. This ensures the user can regain access even if the browser session is lost before first login.
- **Stripe Customer ID**: The `stripe_customer_id` is the primary identifier used to link the Stripe account to the application user.

## 2. Choosing Authentication Methods

Access is initially granted via the **Magic Link** in the welcome email. Once the user has signed in for the first time, they configure and manage their authentication methods in **Settings**.

### Supported Methods
- **Email Link (Passwordless)**: A one-time-use magic link sent via email. Always active as a fallback.
- **OAuth (Google)**: Can be connected in Settings. This links a Google ID to the existing Stripe-verified account.

### Recovery Link Scope
The **Recovery Link** included in the welcome email is intended strictly for the post-payment onboarding window, when the user has **never logged in** (e.g., browser closed before clicking the magic link). Its purpose is solely to let a brand-new subscriber gain their first session.

- If the user **has not yet logged in**: the recovery link at `/registrations/recover` is valid for 7 days and creates a session automatically.
- If the user **has already logged in**: auth method changes must go through **Settings** (section 4). The recovery link should not be used as a regular access mechanism once the account is active.

> **Implementation note**: `RegistrationsController#recover` currently does not check whether an existing session already exists for the user before creating a new one. A guard (`user.sessions.none?` or a flag such as `onboarding_completed`) should be added to enforce this boundary and reject recovery attempts for already-active accounts.

## 3. Login Flow

### Login with Chosen Way
Users can sign in using the method they previously configured:

- **Email Link**:
    1. User enters their email at `/sign_in`.
    2. System sends a magic link with a short-lived `signin` token.
    3. Clicking the link starts the session.
- **OAuth (Google)**:
    1. User clicks "Sign in with Google".
    2. System matches the OAuth `uid` to the existing user.

### Account Recovery
If a user is locked out or the checkout flow was interrupted, they use the **Recovery Link** from their welcome email. This link targets `/registrations/recover` and uses a signed token based on their `stripe_customer_id` to establish a session.

### Public Inertia Auth State
The root landing page remains publicly accessible, but Rails still shares authenticated session state with Inertia through `ApplicationController#inertia_share`.

- `auth` carries the current user, subscription summary, and feature entitlements when a session exists.
- `session_id` carries the current session identifier for authenticated pages that need to issue a `DELETE /sessions/:id` logout action.
- `public_auth_cta` carries the server-owned authenticated header CTA (`label` + `href`) for public pages so Svelte does not hardcode dashboard or setup routing in the landing page.
- The homepage hero stays auth-agnostic for fast first paint: it always renders the public marketing CTA, and authenticated navigation stays in the delayed public header.
- `GET /sign_up` remains available for guests and retained canceled users who need to resubscribe, but active or trialing authenticated sessions are redirected server-side to their next authenticated destination.

## 4. Account Settings & Authentication Updates

Users can change their authentication method at any time via the **Settings** panel under "Sign-in methods".

### Linking Providers
- **Connect Google**: When authenticated, clicking "Connect Google" triggers the OAuth flow. Upon callback, the system detects the active session and updates the `User` record with the Google `uid` and `provider`. 
- **Disconnect Google**: Users can remove the Google link via the `Identity::OauthConnection` controller, reverting to Email Link only.

## 5. Security & Identity Protection

### Stripe Customer ID Integrity
- **Restricted Access**: The use of a Stripe Customer ID recovery token is strictly validated. 
- **No Manual Hijacking**: Tokens are signed using Rails' `generates_token_for`. Using a different or invalid `stripe_customer_id` token will result in rejection.
- **Validation**: Sign-in links and recovery tokens are cryptographically signed and tied to specific user records. Any attempt to forge or reuse these links with different IDs will be rejected.

## 6. Account Deletion

When a user deletes their account, **all forms of access are permanently revoked**. No re-entry is possible through any previously configured authentication method.

### Deletion Flow (`DELETE /sign_up`)
1. User confirms deletion by typing `DELETE` in the Settings panel.
2. `RegistrationsController#destroy` is called (requires authentication).
3. **Stripe subscription is cancelled first**: any active subscription is cancelled via `Stripe::Subscription.cancel`. If the subscription is already cancelled or does not exist, the step is skipped gracefully.
4. `user.destroy!` is called. Because of `has_many :sessions, dependent: :destroy`, **all active sessions are immediately destroyed**, signing the user out on every device.
5. The current session cookie is deleted.
6. The user is redirected to the root path with a confirmation notice.

### What is removed
| Auth method | Removed? | How |
|-------------|----------|-----|
| Magic link tokens | ✅ | Tokens are Rails signed tokens tied to the user record — user record destroyed |
| Recovery link | ✅ | Same — `stripe_customer_recovery` token becomes invalid |
| Google OAuth | ✅ | OAuth `uid`/`provider` are columns on the `User` record — destroyed with it |
| All active sessions | ✅ | `has_many :sessions, dependent: :destroy` |

After deletion, any previously valid link (magic link, recovery link, OAuth callback) will fail to find a user and be rejected. **No access is possible.**

---

## 7. Subscription Cancellation & Non-Renewal

When a subscription is cancelled (immediate or at end-of-period) or fails to renew, the user loses access to the main application but retains access to a limited set of pages so they can reactivate.

### Stripe Webhook Events handled by `ProcessStripeEventJob`

| Stripe event | `subscription_status` set to | Notes |
|---|---|---|
| `customer.subscription.updated` | Synced from Stripe (`active`, `trialing`, `past_due`, `canceled`, `unpaid`, etc.) | Also stores `subscription_ends_at` |
| `customer.subscription.deleted` | `canceled` | Clears `stripe_subscription_id` |
| `invoice.payment_failed` | `past_due` | Triggers a payment-failed email |

These are handled in `ProcessStripeEventJob#perform` which is enqueued by `StripeWebhooksController` on every incoming webhook.

> **Webhook job status**: ✅ Implemented. `customer.subscription.deleted` and `customer.subscription.updated` both correctly update the user's `subscription_status`. The job re-raises exceptions after logging, so failures will be retried by the queue.

### Access Gate (`ApplicationController#require_active_subscription!`)

Runs on every request (except exempted controllers). Logic:

```
trialing?             → allowed
active? && ends_at nil or in future  → allowed
anything else (canceled, past_due, unpaid, expired active) → redirect to /subscription/required
```

### What the user can access after cancellation/non-renewal

| Page / Controller | Accessible? |
|---|---|
| `/subscription/required` | ✅ (exempt) |
| `/settings` | ✅ (exempt) — user can update account details |
| Stripe Billing Portal (`POST /subscriptions/billing_portal`) | ✅ (exempt) — user can resubscribe or update payment |
| `/sign_in`, `/sign_up`, auth callbacks | ✅ (exempt) |
| Dashboard, Forms, Clients, and all other app pages | ❌ → redirected to `/subscription/required` |

### Resubscription Path
From `/subscription/required`, the user can:
1. Click through to the Stripe Billing Portal to resubscribe or update payment.
2. Once Stripe sends a new `customer.subscription.updated` with `status: active`, the webhook job updates `subscription_status` and the user regains full access automatically.

---

## Implementation Summary

- **Routes**: `/sign_up`, `/sign_in`, `/auth/:provider/callback`, `/settings`, `/registrations/recover`, `/subscription/required`.
- **Primary Identifier**: `stripe_customer_id`.
- **Communication**: `UserMailer` handles magic links, welcome notifications, and recovery tokens.
- **Linking Logic**: `SessionsController#omniauth` handles both sign-in and account linking based on `Current.user` presence.
- **Subscription gating**: `ApplicationController#require_active_subscription!` with `subscription_exempt?` allowlist.
- **Stripe event processing**: `ProcessStripeEventJob` handles `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, and `invoice.payment_failed`.
- **Account deletion**: `RegistrationsController#destroy` — cancels Stripe subscription, destroys user (cascades sessions), revokes all auth methods.
