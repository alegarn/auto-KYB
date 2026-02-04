# Feature Specification: Client Portal Subspace

**Feature Branch**: `004-client-portal-subspace`
**Created**: 2026-02-04
**Status**: Draft
**Input**: Subspace plan: "Create a dedicated client subspace where a user links a form to a client, generates a password, and the client can log in to complete the form with partial saves until validation. After validation, the linked form response is locked and marked as validated."

## Clarifications

### Session 2026-02-04

- Q: Should the client portal use a separate authentication flow from user sessions? → A: Yes, login is via `access_token` + password with a signed, HTTP-only cookie scoped to the client portal.
- Q: Should the client-form link be a join model rather than storing `form_id` on `clients`? → A: Yes, use a join model so multiple forms can be linked to a client over time.
- Q: What data structure should be used to render the client form? → A: Use existing `Form` structure and `form_fields` (via `FormDetailSerializer`).
- Q: How should the one-time password reveal work? → A: Reveal once, store password in encrypted session with a 5-minute TTL.
- Q: What should happen after validation? → A: The client form is locked; no further updates are allowed; session is cleared.
- Q: Should portal pages use the authenticated sidebar layout? → A: No, `ClientPortal/*` pages must be excluded from the sidebar layout.
- Q: Should the client portal have rate limiting on login attempts? → A: Yes, throttle login attempts with Rack::Attack and return 429 on threshold.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Link Form to Client (Priority: P1)

As a user, I want to link a form to a client and generate access credentials, so that my client can securely access the form in a dedicated portal.

**Why this priority**: This is the entry point to the client portal workflow. Without linking and credentials, the client cannot access anything.

**Independent Test**: Can be fully tested by creating a link between a client and a form and verifying that credentials are generated and a password reveal page is available.

**Acceptance Scenarios**:

1. **Given** the user is authenticated, **When** they link an existing client to an existing form, **Then** a client-form link is created
2. **Given** a client-form link is created, **When** the link is created successfully, **Then** an access token and one-time password are generated
3. **Given** credentials are generated, **When** the user is redirected to the password reveal page, **Then** the access URL and password are displayed
4. **Given** a client-form link exists, **When** the user requests a new link for the same client and form, **Then** a new link is created (no uniqueness constraint)

---

### User Story 2 - One-Time Password Reveal (Priority: P1)

As a user, I want the generated password to be shown only once and expire quickly, so that credentials are not exposed or reused.

**Why this priority**: Credential exposure is a security risk. One-time reveal and short TTL reduce risk while supporting the workflow.

**Independent Test**: Can be fully tested by loading the reveal page twice and verifying the password is only shown once and expires after 5 minutes.

**Acceptance Scenarios**:

1. **Given** the user has just created a client-form link, **When** the password reveal page loads, **Then** the password is shown exactly once
2. **Given** the password has been revealed, **When** the user refreshes the page or revisits the reveal URL, **Then** the password is no longer available
3. **Given** 5 minutes have elapsed since creation, **When** the reveal page is accessed, **Then** the password is no longer available and an expiration message is shown

---

### User Story 3 - Client Portal Login (Priority: P1)

As a client, I want to log in using an access token and password, so that I can access the form I need to complete.

**Why this priority**: Client login is the gateway to completing the form. Without it, the portal is unusable.

**Independent Test**: Can be fully tested by posting valid/invalid credentials and verifying cookie creation and error handling.

**Acceptance Scenarios**:

1. **Given** a valid access token and password, **When** the client submits the login form, **Then** a signed HTTP-only cookie is set
2. **Given** an invalid password, **When** the client submits the login form, **Then** an error message is shown and no cookie is set
3. **Given** repeated failed logins, **When** the threshold is exceeded, **Then** the system returns a 429 response
4. **Given** the client is logged in, **When** they click logout, **Then** the portal session cookie is cleared

---

### User Story 4 - View Assigned Form (Priority: P1)

As a client, I want to see the assigned form with all fields rendered correctly, so that I can complete the required information.

**Why this priority**: Viewing the form is essential to the completion workflow and must reflect the existing form structure.

**Independent Test**: Can be fully tested by logging in and verifying the form fields render using the existing form definition.

**Acceptance Scenarios**:

1. **Given** the client is logged in, **When** the form page loads, **Then** the form fields are rendered using `form_fields`
2. **Given** the form contains multiple field types, **When** the page renders, **Then** each field uses the correct input type
3. **Given** the client is not logged in, **When** they access the form response page, **Then** they are redirected to the portal login

---

### User Story 5 - Partial Save of Form Response (Priority: P1)

As a client, I want to save my progress without completing the form, so that I can return later and continue.

**Why this priority**: Partial save is critical for long forms and improves completion rates.

**Independent Test**: Can be fully tested by saving the form multiple times and verifying versioned responses and status transitions.

**Acceptance Scenarios**:

1. **Given** the client is logged in, **When** they save the form with partial data, **Then** a new form response is created with an incremented version
2. **Given** no data was previously saved, **When** the first save occurs, **Then** the client-form status changes from `draft` to `filled`
3. **Given** multiple saves occur, **When** a new save is submitted, **Then** the response version increments by 1

---

### User Story 6 - Validate and Lock the Form (Priority: P1)

As a client, I want to submit and validate the form when I am finished, so that the form is locked and marked as validated.

**Why this priority**: Validation is the completion step and must prevent further changes for data integrity.

**Independent Test**: Can be fully tested by sending a validate flag and verifying the link is locked and further saves are rejected.

**Acceptance Scenarios**:

1. **Given** the client has saved data, **When** they submit with validation, **Then** the client-form is marked `validated` and `validated_at` is set
2. **Given** the form is validated, **When** the client attempts to save again, **Then** the update is rejected
3. **Given** the form is validated, **When** the client submits, **Then** the portal session is cleared

---

### User Story 7 - Expiration and Access Control (Priority: P2)

As a user, I want client portal access to expire and be locked after validation, so that outdated links cannot be used.

**Why this priority**: Expiration and locking reduce security risk and enforce data integrity.

**Independent Test**: Can be fully tested by setting an expiration and ensuring access is blocked after the deadline.

**Acceptance Scenarios**:

1. **Given** a client-form has an `expires_at` timestamp, **When** the expiration time has passed, **Then** the link is considered locked
2. **Given** a link is locked, **When** the client tries to access the portal, **Then** access is denied and an error message is shown

---

### Edge Cases

- What happens if a client-form link is deleted after credentials are issued? System denies portal access and shows an error message.
- What happens if the portal cookie is invalid or expired? System redirects to portal login.
- What happens if a client tries to access a form that has been validated? System blocks updates and shows a locked state.
- What happens if the form definition changes after a client has started filling it out? System renders the latest form definition and continues versioned saves.
- What happens if the client tries to submit without any data? System allows save but keeps status as `draft` unless data is present.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a user to create a client-form link between an existing client and form
- **FR-002**: System MUST generate an access token and one-time password for each client-form link
- **FR-003**: System MUST display the password only once and expire it after 5 minutes
- **FR-004**: System MUST allow clients to log in using access token + password
- **FR-005**: System MUST store the client portal session in a signed HTTP-only cookie
- **FR-006**: System MUST provide a portal form page that renders fields from `form_fields`
- **FR-007**: System MUST support partial saves that create versioned form responses
- **FR-008**: System MUST change status from `draft` to `filled` on first save
- **FR-009**: System MUST allow a validation action that sets `validated_at` and marks status `validated`
- **FR-010**: System MUST prevent updates when the client-form is locked (validated or expired)
- **FR-011**: System MUST clear the portal session after validation
- **FR-012**: System MUST enforce `expires_at` access expiration
- **FR-013**: System MUST rate limit portal login attempts and return 429 when exceeded
- **FR-014**: System MUST provide a logout action that clears the portal session cookie
- **FR-015**: System MUST exclude `ClientPortal/*` pages from the authenticated sidebar layout

### Key Entities

- **ClientForm**: Join model linking a client to a form with credentials, status, and access controls.
- **FormResponse**: Versioned response data captured from the client portal.
- **Client Portal Session**: Signed cookie identifying the active client-form session.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of clients can log in successfully on first attempt with valid credentials
- **SC-002**: Form response saves complete in under 1 second for 95th percentile requests
- **SC-003**: Validation locks the form and blocks updates 100% of the time
- **SC-004**: One-time password reveals expire within 5 minutes with zero reuse
- **SC-005**: Login throttling blocks excessive attempts after threshold with 0 false positives in normal usage

## Assumptions

- The user has already created clients and forms before linking
- The portal uses the existing form definition (`structure` + `form_fields`)
- Client portal and user portal sessions are isolated
- The system uses server-side rendering for portal pages via Inertia
- Access tokens are sufficiently random and unique

## Dependencies

- Client and form CRUD features are already implemented
- Authentication and `Current` user context are available for user-side actions
- Inertia routing and page rendering are available for portal pages
- Rack::Attack is available for rate limiting
