# Specification: Automatic Email Invitation Delivery (009)

## 1. Overview
This specification defines the "Automatic Email Invitation Delivery" feature, which allows operators to automatically send portal access credentials (URL and one-time password) to clients via email when a form is shared or replaced.

## 2. User Stories

### US01: Manual Delivery Decision
**As an** operator,
**I want** to be asked whether to send an invitation email immediately after creating or replacing a form link for a client,
**So that** I don't have to manually copy and paste credentials unless I want to.

### US02: Automatic Delivery
**As an** operator,
**I want** to configure my account to automatically send invitation emails whenever a new one-time password is generated,
**So that** I can save time on repetitive tasks.

### US03: Email Template Customization
**As an** operator,
**I want** to customize the subject and body of the invitation email using variables,
**So that** the communication aligns with my brand's voice.

## 3. Functional Requirements

### FR-01: Invitation Decision Point
- **FR-01-1**: Every flow that generates a new `ClientForm` credential (create client with form, update form, remap form) MUST redirect to an invitation delivery decision page.
- **FR-01-2**: The page MUST display a modal with "Send Now" and "Not Now" options.
- **FR-01-3**: If the client email is missing, the "Send Now" button MUST be disabled with an explanatory tooltip.

### FR-02: Email Delivery
- **FR-02-1**: Clicking "Send Now" MUST trigger a synchronous email delivery (using `deliver_now`) to ensure the one-time password is not serialized in background workers.
- **FR-02-2**: The `ClientForm` MUST track delivery status via `invitation_emailed_at` and `invitation_emailed_to`.
- **FR-02-3**: Successful delivery MUST redirect to the password reveal page with a success flash message.

### FR-03: Settings & Automation
- **FR-03-1**: Users MUST have access to an "Invite Email Settings" section in the dashboard settings.
- **FR-03-2**: Users CAN toggle `auto_send` to skip the manual decision modal if all prerequisites (valid email, active subscription) are met.
- **FR-03-3**: Users CAN edit the subject and body templates using a whitelist of placeholders: `{{client_name}}`, `{{form_name}}`, `{{invite_link}}`, `{{password}}`.

### FR-04: Security & Privacy
- **FR-04-1**: The one-time password MUST NEVER be persisted in the database or logs; it lives only in the session during the invitation flow.
- **FR-04-2**: If the session expires or the user navigates away before a decision, the decision MUST be treated as "Not Now" to prevent unauthorized reveal.

## 4. Success Criteria
- **SC-01**: 100% of new form links trigger the delivery decision flow.
- **SC-02**: Users can successfully customize and test templates via a local preview.
- **SC-03**: No raw passwords are leaked into application logs.

## 5. Non-Functional Requirements
- **Performance**: Template rendering and preview MUST be instantaneous (client-side where possible).
- **Reliability**: Email delivery failures must be handled gracefully without consuming the secret.
