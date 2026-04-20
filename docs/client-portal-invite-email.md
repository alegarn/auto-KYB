# Technical Specification: Client Portal Invite Email Decision

**Feature ID:** `013-client-portal-invite-email`
**Date:** 2026-04-10
**Status:** Proposed
**Plan Reference:** [plans/013-client-portal-invite-email-plan.md](../plans/013-client-portal-invite-email-plan.md)

## Purpose

This feature reduces the delay between generating a client portal invitation and actually sending it to the client. Today the operator must manually copy the portal URL and one-time password from the password reveal page and send them outside the product. The new flow inserts a deliberate decision step just before the reveal page so the operator can either send the credentials immediately or keep the current manual handoff path.

The feature must preserve the current one-time-secret behavior, keep the invitation-generation services pure, reuse the existing Rails, Inertia, and Svelte patterns already present in the application, and add a second step that lets users configure invite-email automation and templates from Settings.

## Success Criteria

- Every newly generated client portal invitation routes through a delivery decision step before the one-time password is revealed.
- Choosing `Send now` sends the invitation email to the current client email and then lands on the password reveal page with a clear success message.
- Choosing `Not now` skips delivery and lands on the same password reveal page with no email sent.
- Users can configure whether invite emails should be sent automatically by default when credentials are generated.
- Users can customize the invite email subject and body from Settings using a whitelist of safe variables.
- The raw one-time password is never persisted into Active Job payloads, database columns, or logs.
- Existing invitation creation flows still work for client creation, direct form linking, and form replacement.

## Settings Scope

- The user intent behind `Email sent to client on password reveal` is accepted, but the product copy should be more accurate because the send event happens before the reveal page.
- Recommended settings label: `Send client portal invite automatically when credentials are generated`.
- Settings are user-scoped in the current product because clients and forms are owned directly by `User`.
- Subject and body customization must use safe token interpolation, not ERB or other executable templating.

## Trigger Matrix

The delivery decision step appears only when a brand-new client portal invitation is created.

- **Trigger:** `ClientsController#create` with a selected form.
  - **Reason:** Creating the client and linking the form generates a new `ClientForm` invitation.
- **Trigger:** `ClientFormsController#create` for an existing client.
  - **Reason:** Direct form linking generates a new `ClientForm` invitation.
- **Trigger:** `ClientsController#update` when a different form is assigned and a new invitation is created.
  - **Reason:** Remapping to a different form revokes the old invitation and creates a new one.
- **Trigger:** confirmed replacement of an active client form that already has responses.
  - **Reason:** Once the destructive confirmation is accepted, the replacement path still creates a new invitation and must ask for the email decision.
- **No trigger:** updating client profile fields only.
- **No trigger:** assigning the same form again.
- **No trigger:** visiting an existing `password_reveal` route after the session secret has already been consumed.

## Product Flow

### Step 1 - Invitation creation
- A controller path creates a `ClientForm` invitation through `ClientInvitationService` or through the update/remap service flow.
- The raw password is written to a session-backed invitation store together with:
  - `expires_at`
  - `decision_pending: true`
  - the invitation id

### Step 2 - Settings-driven delivery strategy resolution
- The server loads the effective invite-email setting for the current user.
- The setting includes:
  - automatic send on or off
  - subject template
  - body template
- The server keeps `GET /client_forms/:id/invitation_delivery` side-effect free.
- If automatic send is enabled and the prerequisites are satisfied, the decision page renders a sending interstitial and the frontend immediately posts the existing `Send now` action.
- If automatic send is disabled, the prerequisites are not satisfied, or a previous automatic attempt returned with an alert, the flow falls back to the manual delivery decision prompt.

### Step 3A - Automatic send path
- The decision page shows a non-interactive `Sending portal access...` state instead of the manual prompt.
- The frontend posts the same invitation-delivery endpoint used by the manual `Send now` button.
- The backend validates that:
  - the current user still owns the invitation
  - the subscription still allows access
  - the session secret is still live
  - the client still has an email
- The backend renders the subject and body through the safe template renderer and sends the email synchronously.
- On success, the backend:
  - marks the invitation decision as completed in session
  - records `invitation_emailed_at` and `invitation_emailed_to` on the `ClientForm`
  - redirects to `password_reveal` with a success flash
- On failure, the backend redirects back to the same decision page with an alert, and the frontend must stop auto-posting so the operator sees the manual prompt.

### Step 3B - Manual delivery decision page
- The operator is redirected to `GET /client_forms/:id/invitation_delivery`.
- The page renders an Inertia screen dedicated to this decision and opens a modal immediately.
- The modal copy must clearly show:
  - the client name
  - the recipient email, when present
  - that the operator will still see the one-time password on the next screen

### Step 4A - Send now from the manual decision page
- The operator clicks `Send now`.
- The delivery endpoint validates the same ownership, subscription, session-secret, and email requirements as the automatic send path.
- The backend renders the effective template, sends the email synchronously, and records delivery metadata.

### Step 4B - Not now
- The operator clicks `Not now`.
- The backend marks the invitation decision as completed in session without sending email.
- The backend redirects to `password_reveal` immediately.

### Step 5 - Password reveal
- The operator reaches the existing reveal page.
- The page consumes the raw password from session exactly once.
- If the email was sent, a flash message confirms the recipient.
- If the email was not sent, the page behaves like the current manual fallback.

## UX Specification

### Decision Page
- **Page component:** `Clients/InvitationDeliveryDecision.svelte`
- **Primary interaction:** modal shown on initial render for manual decisions; a sending interstitial shown on initial render for automatic delivery
- **Fallback behavior:** if the modal closes unexpectedly, the page still shows the same actions inline so the operator is not trapped in a blank screen

### Modal Content
- **Title:** `Send portal access now?`
- **Body, with email present:** `Quick KYB can send the client portal link and one-time password to client@example.com now. You will still see the credentials on the next screen.`
- **Body, without email:** `This client does not have an email address yet, so Quick KYB cannot send the portal access automatically. You can continue to the one-time reveal and share it manually.`
- **Primary CTA:** `Send now`
- **Secondary CTA:** `Not now`

### UX Rules
- `Send now` is disabled when the client email is blank.
- `Send now` shows a pending state while the request is in flight.
- The modal must be keyboard accessible and use the same interaction style as the existing confirmation modal pattern.
- The flow must not open a second confirmation modal on the reveal page.
- Automatic send must not briefly render the `Send portal access now?` prompt before the request starts.
- A failed automatic attempt must return to the manual decision prompt instead of retrying automatically in a loop.
- The reveal page keeps its current role as the last step so the operator always has a manual fallback if the email was skipped or later reported missing by the client.
- Automatic send must be framed as a settings-controlled convenience, not a silent replacement for the manual fallback.

### Settings Page
- **Page component:** extend `Settings/Index.svelte`
- **Section title:** `Client invite email`
- **Controls:**
  - automatic-send toggle
  - subject template input
  - body template textarea
  - variable insertion chips or menu
  - sample preview panel
- **Preview data:** fake sample values only
- **Preview responsibility:** client-side only for responsiveness; server-side rendering remains authoritative during actual delivery

### Allowed Variables
- `{{client_name}}`
- `{{client_email}}`
- `{{form_name}}`
- `{{invite_link}}`
- `{{password}}`

### Template Rules
- Unknown variables are rejected on save.
- The subject must strip newline characters to prevent header injection.
- The body remains plain text in user settings. The mailer layout can still wrap it in fixed branded HTML.
- If automatic send is enabled, the effective template must contain both `{{invite_link}}` and `{{password}}`, or the setting must fail validation.

## Technical Architecture

### Routing
- Add a nested member-level delivery resource under `client_forms`.
- Proposed routes:
  - `GET /client_forms/:id/invitation_delivery`
  - `POST /client_forms/:id/invitation_delivery`
- All invitation-creating controller flows redirect to the `GET` route instead of redirecting directly to `password_reveal`.
- Add a dedicated settings mutation route for the invite-email section, for example `PATCH /settings/client_invitation_email`.

### Controllers
- Add a dedicated controller, for example `ClientFormInvitationDeliveriesController`.
- Responsibilities:
  - load and authorize the `ClientForm`
  - read the live invitation secret from the session store
  - render the decision page
  - resolve `Send now` versus `Not now`
- Keep `ClientFormsController#password_reveal` responsible only for guarded reveal behavior and secret consumption.
- Add a dedicated settings controller path for invite-email preferences so `SettingsController` stays thin and does not absorb template-rendering responsibilities.

### Session State
- Add a small object such as `ClientInvitationSessionStore`.
- Responsibilities:
  - `store(client_form_id:, password:, expires_in:)`
  - `fetch_live(client_form_id:)`
  - `decision_pending?(client_form_id:)`
  - `complete_decision(client_form_id:)`
  - `consume_password(client_form_id:)`
- Required metadata in session:
  - `password`
  - `expires_at`
  - `decision_pending`

### Settings Persistence
- Add a dedicated one-to-one model, `ClientInvitationEmailSetting`, owned by `User`.
- Suggested fields:
  - `auto_send:boolean`
  - `subject_template:text`
  - `body_template:text`
- Purpose:
  - explicit validation boundary
  - easier future evolution than a generic JSON blob
  - cleaner ownership and serializer behavior on the Settings page

### Delivery Service
- Add `ClientPortalInvitationDeliveryService`.
- Inputs:
  - `client_form`
  - `password`
- Responsibilities:
  - validate presence of recipient email
  - resolve the effective user setting or default template
  - call the safe renderer
  - call `ClientPortalInvitationMailer.with(...).portal_access.deliver_now`
  - update `invitation_emailed_at` and `invitation_emailed_to`
  - return a small result object for controller branching
- The service must never enqueue the raw password into a background job backend.

### Template Renderer
- Add `ClientPortalInvitationTemplateRenderer`.
- Responsibilities:
  - validate allowed tokens
  - interpolate tokens safely
  - normalize line endings
  - reject unsafe or unknown placeholders
- The renderer must not evaluate ERB, Liquid, Markdown scripts, or any executable template language.

### Mailer
- Add `ClientPortalInvitationMailer`.
- Add both HTML and plain-text templates.
- Required content:
  - workspace or product branding
  - client name, if present
  - portal access URL
  - one-time password
  - a short note that the credentials were generated for access to the shared KYB form
- The mailer subject should be explicit and non-ambiguous, for example `Your Quick KYB secure form access`.
- When a custom template exists, the mailer receives already-rendered subject and body content from the delivery service rather than building template logic itself.

### Persistence
- Add two nullable columns to `client_forms`:
  - `invitation_emailed_at :datetime`
  - `invitation_emailed_to :string`
- Purpose:
  - later status display
  - future resend support
  - basic audit visibility per invitation
- The raw password must not be stored in the database.

## Security Requirements

- The raw password remains session-backed until reveal or expiry.
- The raw password must not be serialized into Active Job arguments.
- The raw password must not be written to Rails logs, application events, or database fields.
- The delivery controller must authorize the current user against the underlying client ownership, just like the reveal flow does.
- If the session secret is expired or missing, the send path must fail closed and never attempt to email a partial invitation.
- The Settings page preview must never expose live client data or a real one-time password.
- Header injection must be prevented by validating and normalizing the custom subject template.

## Failure Handling

- **Missing client email:** keep `Send now` disabled on the page and reject the POST server-side with a validation error if the UI is bypassed.
- **Automatic send enabled but email missing:** skip automatic delivery and fall back to the manual decision page.
- **Expired session secret:** redirect to the reveal page with the existing expired message, or render the decision page with an error and no send action. In both cases, no email is sent.
- **Mailer failure:** stay on the decision page, show an alert, do not clear the secret, and keep `Not now` available.
- **Double-submit:** disable the button in the frontend and make the POST idempotent by checking `decision_pending` before sending.
- **Unauthorized access:** redirect away exactly like the existing client form ownership guard.
- **Invalid template configuration:** reject the settings update with 422 errors and keep the previous persisted template untouched.

## Testing Strategy

### Request Specs
- Update existing redirect expectations in request specs that currently go straight to `password_reveal`.
- Add request coverage for the new delivery controller:
  - `GET invitation_delivery` with a live secret
  - `GET invitation_delivery` with an expired or missing secret
  - `POST invitation_delivery` with `send_now: true`
  - `POST invitation_delivery` with `send_now: false`
  - `POST invitation_delivery` when the client email is missing
  - `GET password_reveal` while `decision_pending` is still true
- Add request coverage for the settings update flow:
  - valid toggle-only change
  - valid subject and body customization
  - unknown placeholder rejection
  - required placeholder validation when auto-send is enabled

### Service Specs
- Add service specs for `ClientPortalInvitationDeliveryService`:
  - success path
  - missing email
  - mailer exception
  - metadata persistence on success only
- Add service specs for `ClientPortalInvitationTemplateRenderer`:
  - valid interpolation
  - unknown token rejection
  - subject normalization
  - plain-text body rendering

### Mailer Specs
- Add mailer specs for:
  - recipient
  - subject
  - presence of access URL
  - presence of one-time password
  - text and HTML body coverage

### System Specs
- Add or update JS system coverage for:
  - creating a client with a linked form, then choosing `Send now`
  - creating a client with a linked form, then choosing `Not now`
  - changing a client to a different form and confirming the replace flow before the delivery decision appears
- Add JS system coverage for the Settings page:
  - enable automatic sending and save
  - customize subject and body templates
  - confirm preview updates locally
  - create a new invitation and confirm the configured behavior applies

## Out Of Scope

- Editing the client email directly inside the decision modal
- Rich-text or HTML template editing in Settings
- Retry queues or async resend logic for the one-time password email
- A resend action from the client detail page
- Replacing the password reveal page entirely

## Notes For Implementation

- The safest first version is synchronous delivery for `Send now` because this feature handles a one-time secret.
- Step 1 remains the safe manual delivery decision flow.
- Step 2 adds per-user settings on top of Step 1 rather than replacing it as the only path.
- The decision page should reuse the existing design language rather than introducing a second modal system.
- Documentation and automated tests are required in the same implementation branch so the new invitation flow stays explicit and maintainable.