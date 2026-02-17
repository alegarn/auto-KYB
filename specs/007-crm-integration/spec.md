# Feature Specification: CRM Integration

**Feature Branch**: `007-crm-integration`
**Created**: 2026-02-17
**Status**: Draft
**Input**: User description: "In the app, user should be able to export its client's data (file included) directly to zoho/salesforce/hubspot crm. The user, after authorizing the oauth 2 connection between the crm and the app, can create forms/clients and when the forms are validated by the client in the portal, the data are transferred to the crm. The data are destroyed 1 day after the transfer is successful."

## Clarifications

### Session 2026-02-17

- Q: When a user has multiple active CRM connections, how should automatic data transfers be handled? → A: Transfer to ALL active CRM connections sequentially (one at a time)
- Q: What is the retry strategy for failed data transfers? → A: 3 retries with exponential backoff (30s, 2min, 10min intervals)
- Q: When transferring to multiple CRMs sequentially, what happens if some transfers succeed and others fail? → A: Each CRM transfer is independent; success/failure tracked separately
- Q: When file transfer fails but other data (client info, form responses) succeeds, how should this be handled? → A: Record as partial success; notify user of file failure
- Q: How should OAuth token refresh be handled when access tokens expire? → A: Automatic refresh using refresh token; notify user if refresh fails

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Authorize CRM Connection (Priority: P1)

As a user, I want to authorize a connection between my CRM account (Zoho, Salesforce, or HubSpot) and the application using OAuth2, so that client data can be automatically exported to my CRM.

**Why this priority**: Without CRM authorization, no data transfer can occur. This is the foundational capability required for all subsequent CRM integration features. Users must establish trust and permissions before any data flows to external systems.

**Independent Test**: Can be fully tested by initiating OAuth2 authorization flow with each CRM provider, verifying the authorization redirect, user consent, and successful connection establishment.

**Acceptance Scenarios**:

1. **Given** the user is logged in and has no CRM connections, **When** the user clicks "Connect CRM" and selects a provider (Zoho/Salesforce/HubSpot), **Then** the user is redirected to the CRM provider's authorization page
2. **Given** the user is on the CRM provider's authorization page, **When** the user grants the required permissions, **Then** the user is redirected back to the application and the CRM connection is established with OAuth tokens stored for automatic refresh
3. **Given** the user has an active CRM connection, **When** the user views their CRM settings, **Then** the connected CRM provider and connection status are displayed
4. **Given** the user has an active CRM connection, **When** the user clicks "Disconnect" for a CRM, **Then** the connection is terminated and the user is no longer able to export data to that CRM
5. **Given** the user is on the CRM authorization page, **When** the user denies the authorization request, **Then** the user is redirected back to the application with an appropriate error message explaining authorization was denied

---

### User Story 2 - Automatic Data Transfer on Form Validation (Priority: P1)

As a user, I want client data (including form responses and uploaded files) to be automatically transferred to my connected CRM when a client validates their form in the portal, so that I don't need to manually export or re-enter data.

**Why this priority**: This is the core value proposition of the feature - automatic data synchronization eliminates manual data entry, reduces errors, and saves time. Without this, users would need to manually export and import data, defeating the purpose of integration.

**Independent Test**: Can be fully tested by creating a client with forms, having the client validate forms in the portal, and verifying the data appears in the connected CRM.

**Acceptance Scenarios**:

1. **Given** the user has an active CRM connection, **When** a client validates their form in the portal, **Then** the client's data is automatically transferred to the connected CRM
2. **Given** the user has an active CRM connection, **When** the form validation is complete and data transfer is initiated, **Then** the transfer includes client information, form responses, and uploaded files
3. **Given** the user has multiple CRM connections, **When** a client validates their form, **Then** the data is transferred to all active CRM connections sequentially (one at a time)
4. **Given** the user has an active CRM connection, **When** the data transfer is successful, **Then** the user is notified of the successful transfer (per CRM)
5. **Given** the user has an active CRM connection, **When** the data transfer fails, **Then** the system attempts to retry the transfer and notifies the user if retries are exhausted (per CRM)

---

### User Story 3 - Data Retention and Cleanup (Priority: P2)

As a system, I want to destroy transferred data from the application storage 1 day after successful transfer to CRM, so that storage costs are minimized and data privacy is maintained.

**Why this priority**: Data cleanup is important for cost optimization and privacy compliance, but it's a secondary concern compared to ensuring data is successfully transferred. Users need the transfer to work reliably before worrying about cleanup.

**Independent Test**: Can be fully tested by triggering a successful data transfer, waiting 1 day, and verifying the data is removed from application storage while remaining in the CRM.

**Acceptance Scenarios**:

1. **Given** a client's data has been successfully transferred to CRM, **When** 1 day has elapsed since the successful transfer, **Then** the transferred data is removed from application storage
2. **Given** a client's data transfer has failed, **When** 1 day has elapsed, **Then** the data is NOT removed from application storage (retained for retry)
3. **Given** a client's data transfer is in progress, **When** 1 day has elapsed, **Then** the data is NOT removed from application storage
4. **Given** data is scheduled for cleanup, **When** the cleanup process runs, **Then** a log entry is created for audit purposes
5. **Given** a user manually re-exports data before the 1-day cleanup, **When** the cleanup process runs, **Then** the data is removed based on the most recent successful transfer timestamp

---

### User Story 4 - Manual Data Export (Priority: P2)

As a user, I want to manually export client data to my connected CRM, so that I can export historical data or re-export data if the automatic transfer failed.

**Why this priority**: Manual export provides flexibility for edge cases and historical data migration. Users may need to export existing clients' data that was created before CRM integration was enabled.

**Independent Test**: Can be fully tested by selecting a client and triggering manual export, then verifying the data appears in the connected CRM.

**Acceptance Scenarios**:

1. **Given** the user has an active CRM connection, **When** the user selects a client and clicks "Export to CRM", **Then** the client's data is transferred to the connected CRM
2. **Given** the user has multiple CRM connections, **When** the user clicks "Export to CRM", **Then** the user can select which CRM(s) to export to
3. **Given** the user initiates a manual export, **When** the export is in progress, **Then** the user sees a progress indicator
4. **Given** the user initiates a manual export, **When** the export completes successfully, **Then** the user is notified of the successful export
5. **Given** the user initiates a manual export, **When** the export fails, **Then** the user is notified with the reason for failure

---

### User Story 5 - Transfer Status and History (Priority: P3)

As a user, I want to view the status and history of data transfers to CRM, so that I can troubleshoot issues and verify that data has been successfully exported.

**Why this priority**: Visibility into transfer status is important for debugging and confidence, but users can operate without it if the primary transfer functionality works reliably. This is a nice-to-have feature that enhances user experience.

**Independent Test**: Can be fully tested by viewing the transfer history page and verifying that past transfers show correct status and timestamps.

**Acceptance Scenarios**:

1. **Given** the user has performed data transfers, **When** the user views the transfer history page, **Then** all transfers are listed with their status (pending, success, failed)
2. **Given** the transfer history is displayed, **When** the user clicks on a transfer entry, **Then** detailed information about the transfer is shown including timestamp, CRM provider, and data items transferred
3. **Given** a transfer has failed, **When** the user views the transfer details, **Then** an error message or reason for failure is displayed
4. **Given** the transfer history is displayed, **When** the list contains many entries, **Then** the list is paginated or scrollable with appropriate navigation
5. **Given** the user filters the transfer history by status, **When** the filter is applied, **Then** only transfers matching the selected status are displayed

---

### Edge Cases

- What happens when the user has no active CRM connections and a client validates their form? The form validation proceeds normally, but no data transfer occurs. The user is notified that no CRM connection is active.
- What happens when the CRM provider's API is temporarily unavailable during transfer? The system implements retry logic with 3 retries using exponential backoff (30s, 2min, 10min intervals) and notifies the user if all retry attempts fail.
- What happens when the client data exceeds CRM API limits (e.g., file size too large)? The transfer fails with an appropriate error message, and the user is notified of the specific limitation.
- What happens when OAuth access tokens expire? The system automatically refreshes tokens using refresh tokens. If refresh fails, the user is notified and the connection is marked as requiring re-authorization.
- What happens when the user disconnects a CRM while a transfer is in progress? The transfer completes if already initiated; new transfers are not started for the disconnected CRM. Each CRM transfer is tracked independently.
- What happens when some CRM transfers succeed and others fail? Each CRM transfer is treated independently; success/failure is tracked separately per CRM. Failed transfers are retried independently.
- What happens when a client validates multiple forms in quick succession? Each form validation triggers an independent transfer; the system processes transfers sequentially for all active CRM connections.
- What happens when uploaded files cannot be transferred to CRM (e.g., unsupported file type)? The transfer is recorded as partial success with file-specific errors; user is notified of file failure details. Other data and files are still transferred successfully.
- What happens when the user has multiple clients with the same data (e.g., duplicate company names)? Each client is treated independently; duplicates are not prevented as they may represent different entities.
- What happens when the cleanup process fails to remove data? The system logs the error and retries cleanup on the next scheduled run; data remains until successfully removed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to authorize OAuth2 connections with Zoho CRM
- **FR-002**: System MUST allow users to authorize OAuth2 connections with Salesforce CRM
- **FR-003**: System MUST allow users to authorize OAuth2 connections with HubSpot CRM
- **FR-004**: System MUST automatically transfer client data to all connected CRM(s) sequentially when a client validates their form in the portal
- **FR-005**: System MUST transfer client information including name, company, email, phone, and address
- **FR-006**: System MUST transfer form response data for validated forms
- **FR-007**: System MUST transfer uploaded files associated with the client and forms
- **FR-008**: System MUST notify users of successful data transfers
- **FR-009**: System MUST notify users of failed data transfers with error details
- **FR-010**: System MUST implement retry logic for failed transfers with 3 retries using exponential backoff (30s, 2min, 10min intervals)
- **FR-011**: System MUST allow users to manually export client data to connected CRM(s)
- **FR-012**: System MUST allow users to disconnect CRM connections
- **FR-013**: System MUST destroy transferred data from application storage 1 day after successful transfer
- **FR-014**: System MUST retain data if transfer fails or is still in progress after 1 day
- **FR-015**: System MUST display transfer status and history to users
- **FR-016**: System MUST support multiple simultaneous CRM connections per user
- **FR-017**: System MUST log all transfer activities for audit purposes
- **FR-018**: System MUST validate CRM connection status before attempting transfers
- **FR-019**: System MUST handle file size limitations from CRM providers gracefully
- **FR-020**: System MUST map application data fields to appropriate CRM fields for each provider
- **FR-021**: System MUST track transfer status independently for each CRM connection when multiple transfers occur
- **FR-022**: System MUST record partial success status when file transfers fail but other data succeeds
- **FR-023**: System MUST notify users of file-specific transfer failures with detailed error information
- **FR-024**: System MUST automatically refresh OAuth access tokens using refresh tokens
- **FR-025**: System MUST notify users when OAuth token refresh fails and connection requires re-authorization

### Key Entities

- **CRM Connection**: Represents an authorized OAuth2 connection between a user and a CRM provider (Zoho, Salesforce, or HubSpot). Contains connection credentials, status, and provider-specific metadata.
- **Data Transfer**: Represents a single data export operation from the application to a CRM. Contains transfer status, timestamp, CRM provider reference, and list of data items transferred.
- **Transfer Log**: An audit record of all transfer activities including successful transfers, failures, retries, and cleanup operations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete CRM authorization in under 3 minutes
- **SC-002**: Data transfer to CRM completes within 30 seconds of form validation for standard client data (excluding large files)
- **SC-003**: 95% of automatic data transfers succeed on first attempt
- **SC-004**: Failed transfers are successfully retried and completed within 5 minutes for 90% of cases
- **SC-005**: Users are notified of transfer status within 10 seconds of completion
- **SC-006**: Data cleanup removes transferred data within 1 hour of the 1-day retention period
- **SC-007**: 100% of transfer activities are logged for audit purposes
- **SC-008**: Users can locate and view transfer history for any client in under 30 seconds
- **SC-009**: System supports at least 1000 concurrent users with active CRM connections without performance degradation
- **SC-010**: 90% of users successfully complete their first CRM export without needing support

## Assumptions

- OAuth2 authorization flow follows standard industry practices for each CRM provider
- CRM providers offer APIs that support creating/updating client records and file attachments
- Standard client data fields (name, company, email, phone, address) can be mapped to equivalent fields in all three CRM providers
- File uploads are within reasonable size limits supported by CRM providers (typically under 25MB per file)
- Users have appropriate permissions in their CRM accounts to create and update records
- Data transfer is one-way (application to CRM) and does not require bidirectional synchronization
- The 1-day retention period starts from the timestamp of successful transfer completion
- Cleanup process runs periodically (e.g., hourly) to identify and remove eligible data

## Dependencies

- Existing client management functionality (feature 003)
- Existing form management functionality (feature 002)
- Existing client portal and form validation functionality (feature 004)
- Existing file upload functionality (feature 006)
