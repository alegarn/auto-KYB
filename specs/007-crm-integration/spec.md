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
- Q: When testing CRM connection, what should the user be able to verify? → A: Both preview field mappings AND send test data for full verification
- Q: When sending test data to CRM, how should the test data be generated and what should happen to it in the CRM? → A: Use placeholder/sample data (e.g., 'Test Client', 'test@example.com') and mark records as test data in CRM (flagged for easy deletion)
- Q: Where in the UI should the CRM test connection feature be available? → A: Both: In CRM settings (general connection test) AND on form pages (form-specific mapping test)
- Q: When a CRM test connection fails, what information should be displayed to the user? → A: Categorized errors (connection, authentication, field mapping, file upload) with specific guidance for each type
- Q: How does the system ensure data type compatibility between form fields and CRM properties? → A: The system uses a compatibility matrix (e.g., 'number' matches 'integer', 'float', 'decimal') and displays a "Type mismatch" warning in the UI if incompatible types are selected.
- Q: How does the system handle mapping to multiple CRM objects (Contact vs Company)? → A: The UI allows selecting the target object type (Contact or Company) for each field. An "Export Preview" summary indicates if both records will be created and if they can be successfully linked (e.g., checking for required identifiers like 'email' for Contacts or 'name/domain' for Companies).
- Q: Can users create new properties in their CRM directly from the app? → A: Yes, users can select "+ Create as Custom Contact/Company Property" which will trigger the creation of that property in the CRM during the export process.
- Q: Is there an automated way to set up mappings? → A: Yes, an "Auto-Map Fields" feature uses fuzzy matching and type validation to suggest mappings for all form fields.

### Session 2026-03-19

- Q: Should users be able to disable automatic CRM export when a client validates a portal submission? → A: Yes. A per-user setting controls whether validated portal submissions auto-export to CRM or stay local until manual export.
- Q: If automatic portal export is disabled, how should CRM-linked clients still be updated? → A: The manual export path from the client page remains available and becomes the fallback for portal-submitted data.
- Q: For CRM-linked clients on the back-office edit page, is fetching fresh CRM data automatic? → A: No. Fetching remains a manual action via the dedicated CRM prefill action.
- Q: For CRM-linked clients on the back-office edit page, should saving local edits update the CRM automatically? → A: Yes, if the client is linked and the CRM connection is active, saving the edit form automatically updates the linked CRM profile and company data.
- Q: Should the linked-client edit warning dismissal be shared across devices? → A: No. The informational modal is dismissed once per browser/device, while the inline warning remains visible on the page.

### Session 2026-03-20

- Q: How should unread CRM transfer failures be surfaced? → A: Use a durable user-level last-seen timestamp for the sidebar badge and a session-scoped toast marker for the global alert so users only see new failures.
- Q: When should CRM transfer failures be marked as seen? → A: Visiting the CRM Transfers page marks current failures as seen and advances the session toast marker.
- Q: What wording should be shown when `create_crm_contact` schedules work asynchronously? → A: The UI should say the CRM contact creation was queued and point users to CRM Transfers.
- Q: How should `client_create_sync` retries behave? → A: They must be idempotent, reusing existing CRM identifiers when available and deduplicating open pending/processing transfers for the same client and CRM connection.

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
6. **Given** the user disabled automatic CRM sync in settings, **When** a client validates their form in the portal, **Then** the validation completes normally but no CRM export is triggered automatically

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
6. **Given** automatic CRM sync after portal submission is disabled in settings, **When** the user wants to push validated submission data to CRM, **Then** the client page manual export flow remains available as the supported fallback

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

### User Story 6 - CRM Connection Testing and Field Mapping Preview (Priority: P1)

As a user, I want to test my CRM connection and preview field mappings when creating or updating forms, so that I can verify data will be transferred correctly to the right fields in the CRM before real client data is sent.

**Why this priority**: This is critical for user confidence and data integrity. Users need to verify their CRM integration is working correctly and that form fields map properly to CRM fields before relying on automatic data transfers. Without testing, users may discover mapping issues only after real client data has been incorrectly transferred, leading to data quality problems and manual cleanup efforts.

**Independent Test**: Can be fully tested by creating a form, clicking "Test CRM Connection", verifying the mapping preview, sending test data, and confirming the test record appears correctly in the CRM.

**Acceptance Scenarios**:

1. **Given** the user has an active CRM connection, **When** the user views the CRM settings page, **Then** a "Test Connection" button is displayed for each connected CRM
2. **Given** the user clicks "Test Connection" in CRM settings, **When** the test completes successfully, **Then** the user sees a success message with connection status and API credential validity
3. **Given** the user clicks "Test Connection" in CRM settings, **When** the test fails, **Then** the user sees a categorized error message (connection, authentication, field mapping, or file upload) with specific guidance for resolution
4. **Given** the user is creating or editing a form with CRM integration enabled, **When** the user clicks "Test CRM Mapping", **Then** the user sees a preview of how each form field maps to the corresponding CRM field
5. **Given** the user is viewing the field mapping preview, **When** a form field cannot be mapped to a CRM field, **Then** the field is highlighted with a warning and the user is informed of the mapping limitation
6. **Given** the user clicks "Send Test Data" from the form page, **When** the test data is sent successfully, **Then** a test record is created in the CRM using placeholder/sample data (e.g., 'Test Client', 'test@example.com') and marked as test data
7. **Given** the test data is sent to CRM, **When** the user views the test record in CRM, **Then** the record is clearly flagged as test data for easy identification and deletion
8. **Given** the user sends test data to multiple CRM connections, **When** the test is complete, **Then** the user sees a summary showing success/failure status for each CRM with links to view the test records
9. **Given** the user sends test data including file uploads, **When** the test completes, **Then** test files are uploaded to the CRM and the user can verify the file transfer is working correctly
10. **Given** the user has multiple CRM connections, **When** the user clicks "Test CRM Mapping" on a form, **Then** the user can select which CRM(s) to test and see mapping previews for each selected provider

---

### User Story 7 - CRM Selection in Settings (Priority: P1)

As a user, I want to choose which CRM providers I enable from the application settings (Zoho, Salesforce, HubSpot), so that only selected CRMs are available for imports/exports and automatic transfers.

**Why this priority**: Users must control which CRM providers the application may interact with to avoid accidental exports and to limit visible options in form mapping and manual export flows.

**Independent Test**: Can be tested by visiting CRM settings, toggling available CRM providers, and confirming the available options in form mapping and manual export UI update accordingly.

**Acceptance Scenarios**:

1. **Given** the user is logged in, **When** they open CRM settings, **Then** they can enable or disable Zoho, Salesforce, and HubSpot individually
2. **Given** the user disables a CRM provider, **When** they view form mapping or manual export screens, **Then** the disabled provider is not listed as an export or mapping target
3. **Given** the user enables a CRM provider, **When** they then connect that provider using OAuth, **Then** the provider becomes available for exports, imports and test mapping
4. **Given** the user has multiple providers enabled, **When** they choose defaults in settings, **Then** default selection is pre-selected in manual export and mapping dialogs
5. **Given** no CRM providers are connected, **When** creating or editing a client, **Then** no CRM-related UI components (sync widgets, import/export buttons) are loaded or displayed to the user
6. **Given** a CRM is connected, **When** editing an existing client that is already linked to the CRM, **Then** the CRM sync strategy widget is hidden to avoid redundant import/link prompts
7. **Given** the user is in settings, **When** they toggle automatic CRM sync after client portal submission, **Then** future validated portal submissions follow the selected automatic or manual-export behavior

---

### User Story 8 - Import Leads/Contacts from CRM (Priority: P2)

As a user, I want to import chosen leads/contacts (CRM wording) from a connected CRM into the application as clients (including associated company data), so that I can onboard existing CRM records into the app and update their client/company profiles with portal/form data.

**Why this priority**: Importing contacts/leads is essential for migrating existing customers and enabling a two-way workflow where CRM-origin data becomes a managed client record in the application.

**Independent Test**: Can be tested by selecting a subset of contacts/leads in the UI, importing them, and verifying created client and company records in the application reflect CRM data.

**Acceptance Scenarios**:

1. **Given** the user has at least one active CRM connection, **When** they open the "Import from CRM" flow, **Then** they can browse/search CRM leads/contacts and select which records to import
2. **Given** the user selects a lead/contact to import, **When** the import completes, **Then** a client record (and associated company record if present) is created in the application with CRM-provided fields (name, company, email, phone, address)
3. **Given** the user imports multiple records, **When** the import completes, **Then** the UI displays a summary of imported records and any partial failures with reasons
4. **Given** the user later receives updated data in the CRM for an imported record, **When** they run a sync or re-import for that record, **Then** the application updates the client/company info while preserving any locally-collected form data unless the user opts to overwrite
5. **Given** imported records include files/attachments, **When** the import is performed, **Then** files are associated with the created client/company where supported and any file-size/provider limits are surfaced as warnings or errors

---

### User Story 9 - Export Client to CRM as Contact/Lead (Priority: P2)

As a user, I want to export a client from the application to a connected CRM as a contact or lead (CRM wording) including company data and recent form responses, so that CRM systems are kept up-to-date from the app.

**Why this priority**: Allows integrating application-managed client lifecycle with the CRM sales/marketing workflows and supports both one-off manual exports and automated exports on form validation.

**Independent Test**: Can be tested by selecting a client and exporting to a connected CRM, then verifying the created contact/lead and associated company record in the CRM.

**Acceptance Scenarios**:

1. **Given** the user has at least one active CRM connection, **When** they open a client's page and click "Export to CRM", **Then** they can choose the target CRM(s) and whether to create a contact or a lead where the provider differentiates
2. **Given** the user exports a client, **When** the export completes successfully, **Then** the created CRM record contains client fields (name, company, email, phone, address) and mapped form responses
3. **Given** the client has an existing CRM identifier stored, **When** the user exports, **Then** the system updates the existing CRM record rather than creating duplicates (where matching rules exist)
4. **Given** the exported payload includes files, **When** the CRM does not support the file type or size, **Then** the export records partial success and surfaces file-specific errors to the user
5. **Given** the user exports to multiple CRMs, **When** some exports succeed and others fail, **Then** the UI displays per-CRM statuses and retry options for failed exports

---

### User Story 10 - Form-Level CRM Field Mapping Configuration (Priority: P1)

As a user, I want to configure how form fields map to CRM properties directly within the form builder, so that I have clear, contextual control over where collected data is exported.

**Why this priority**: Users need explicit control over how dynamic form data corresponds to CRM records. Auto-mapping might miss edge cases, and giving users the choice to use existing CRM default properties or dynamically create new custom properties in the CRM guarantees accurate data representation.

**Independent Test**: Can be tested mathematically in a mock environment by interacting with the Form Builder's "CRM Mapping" tab, selecting "Create Custom Property" vs an "Existing Property", and verifying the payload structures generated upon form submission.

**Acceptance Scenarios**:

1. **Given** the user is editing a form, **When** they open the CRM Mapping settings, **Then** they see a table matching Form Fields to corresponding CRM Properties for the selected CRM
2. **Given** the user adds a new form field, **When** they view the mapping settings, **Then** the system automatically auto-suggests a corresponding CRM property using fuzzy matching
3. **Given** a form field does not match any existing standard CRM property, **When** the mapper loads, **Then** the field defaults to the "Create as Custom Property" action
4. **Given** the user configures a field to "Create as Custom Property", **When** the form mapping is saved (or form submitted), **Then** the application asynchronously creates that custom property in the CRM via API
5. **Given** the user wants to map standard app fields (e.g. client name, company email), **When** they check the standard mappings section in global settings, **Then** they see the hardcoded mappings which represent where core entities route to their CRM

---

### User Story 11 - CRM Property Data Type Validation (Priority: P2)

As a user, I want to see warnings when I map a form field to an incompatible CRM property type, so that I can avoid data truncation or transfer failures due to type mismatches.

**Why this priority**: Prevents silent data loss or API errors. While users can still save the mapping, being informed of the "DataType" mismatch (e.g., mapping a 'text' field to a CRM 'number' property) allows them to correct the mapping before real data is sent.

**Independent Test**: Can be tested by selecting a 'long text' form field and mapping it to a 'boolean' CRM property, then verifying that a "Type mismatch" warning is displayed in the UI.

**Acceptance Scenarios**:

1. **Given** the user is in the CRM mapping modal, **When** they select a CRM property with a type (e.g., 'number') that is incompatible with the form field type (e.g., 'text' or 'select'), **Then** a "Type mismatch" warning is displayed below the field
2. **Given** a type mismatch is present, **When** the user switches to a compatible CRM property, **Then** the warning automatically disappears
3. **Given** multiple CRM providers are active, **When** the user checks different provider tabs, **Then** type validation is performed independently for each provider's unique property schema

---

### User Story 12 - CRM Object Creation Preview and Required Identifiers (Priority: P1)

As a user, I want a clear preview of which CRM object records (Contact, Company) will be created and whether they contain the required identifiers, so that I can ensure the CRM integration will successfully link and create records.

**Why this priority**: CRM APIs often have mandatory fields (e.g., HubSpot requires 'name' or 'domain' for Companies). Without these, the entire export might fail or create disconnected records. A real-time "Export Preview" makes these requirements visible and actionable.

**Independent Test**: Can be tested by mapping only 'non-identifier' fields for a Company and verifying the "Company (incomplete)" warning appears, then mapping a 'name' field and verifying it changes to "Ready".

**Acceptance Scenarios**:

1. **Given** the user is in the mapping modal, **When** they map at least one field to a Contact, **Then** the "Contact" status in the Export Preview is marked as "Ready"
2. **Given** the user maps fields to both Contact and Company, **When** both have at least one field mapped, **Then** the "Linked" status indicates the records will be associated in the CRM
3. **Given** a CRM (like HubSpot) requires a company 'name' for creation, **When** the user maps other company fields but NOT 'name', **Then** a specific warning listing the missing required identifier is displayed
4. **Given** the user maps no fields to a specific object type, **When** viewing the Export Preview, **Then** the status for that object type shows "No [Object Type]" to indicate it will be skipped during export

---

### User Story 13 - Automation of Field Mapping (Priority: P2)

As a user, I want to automatically match my form fields to CRM properties at the click of a button, so that I don't have to manually select dozens of properties for complex forms.

**Why this priority**: High UX value for efficiency. In complex forms with many KYC/KYB fields, manual mapping is tedious and error-prone. Automation handles the 80% of obvious matches, leaving the user to only review and adjust exceptions.

**Independent Test**: Can be tested by opening a form with fields like "First Name", "Company Email", clicking "Auto-Map Fields", and verifying they are correctly mapped to "firstname" and "email" in the CRM.

**Acceptance Scenarios**:

1. **Given** the user has complex forms and an active CRM, **When** they click "Auto-Map Fields", **Then** the system uses fuzzy matching and type validation to automatically suggest mappings for as many fields as possible
2. **Given** auto-mapping is triggered, **When** a field already has a manual mapping, **Then** the manual mapping is preserved and NOT overwritten by the automation
3. **Given** auto-mapping finds a match but the types are incompatible, **When** analyzing the result, **Then** the system should prioritize compatible types or surface a warning if a mismatching name is the best match

---

### User Story 14 - Automatic CRM Sync for Linked Client Edits (Priority: P1)

As a user, I want saving a CRM-linked client from the back-office edit page to update the linked CRM profile automatically, while keeping CRM fetch as a manual action, so that my local edits and CRM records stay aligned without unexpected overwrites.

**Why this priority**: Once a client is explicitly linked to CRM, the edit page becomes a high-frequency operational workflow. If local profile changes do not propagate back to CRM, users quickly create divergence between the app and their CRM.

**Independent Test**: Can be fully tested by opening a CRM-linked client edit page, confirming the manual-fetch warning appears, saving profile changes, and verifying the linked CRM sync service is triggered while the local client is updated.

**Acceptance Scenarios**:

1. **Given** a client is linked to an active CRM connection, **When** the user opens the edit page, **Then** the page displays an inline warning that CRM fetch is manual but saving changes updates the linked CRM automatically
2. **Given** a client is linked to an active CRM connection, **When** the user opens the edit page for the first time in a browser, **Then** an informational modal explains that fetching CRM data is manual and saving changes updates the linked CRM automatically
3. **Given** the user dismisses the informational modal, **When** they continue editing in the same browser, **Then** the modal stays dismissed for later visits while the inline warning remains visible
4. **Given** a client is linked to an active CRM connection, **When** the user clicks the manual CRM prefill action, **Then** fresh CRM data is fetched only for that explicit action and not automatically on page load
5. **Given** a client is linked to an active CRM connection, **When** the user saves profile or company changes from the edit page, **Then** the application updates the local client and triggers an update of the linked CRM contact/company record
6. **Given** a client is linked to CRM but the connection is inactive, **When** the user views or saves the edit page, **Then** the page warns that changes stay local until the CRM connection becomes active again

---

### User Story 15 - CRM Transfer Failure Signals And Review (Priority: P2)

As a user, I want new CRM transfer failures to appear as a sidebar badge and a one-time global alert, so that I can review fresh failures quickly without seeing the same alert on every page load.

**Why this priority**: Transfer visibility is important for support and recovery. Users need a durable indicator for unread failures plus a lightweight toast for immediate attention, but the alert must not become noisy or repetitive.

**Independent Test**: Can be fully tested by creating a failed CRM transfer, visiting authenticated pages to observe the sidebar badge and toast, then opening CRM Transfers to mark failures as seen and confirming the toast does not repeat on refresh.

**Acceptance Scenarios**:

1. **Given** unread CRM transfer failures exist, **When** the user views an authenticated page, **Then** the CRM Transfers sidebar item shows an unread badge with the current failed count
2. **Given** a new unread CRM transfer failure exists, **When** the user enters the app on any authenticated page, **Then** a single toast appears linking them to CRM Transfers
3. **Given** the user opens the CRM Transfers page, **When** the page loads successfully, **Then** the current failures are marked as seen and the toast does not reappear on refresh
4. **Given** a newer failure occurs after the user has already seen previous failures, **When** shared CRM transfer signals are recomputed, **Then** the badge and toast update for the new failure only

---

### User Story 16 - Idempotent Client Create Sync Retries (Priority: P1)

As a user, I want create-sync CRM transfers to retry safely without creating duplicate contacts or companies, so that failed transfers can recover without corrupting my CRM data.

**Why this priority**: The client-create path is high risk because a partial failure can create a remote record before later steps fail. Retrying must reuse discovered identifiers and avoid duplicate in-flight work.

**Independent Test**: Can be fully tested by forcing a partial client-create sync failure, retrying it, and confirming the CRM reuses the original identifiers without creating duplicate contact/company records.

**Acceptance Scenarios**:

1. **Given** a `client_create_sync` transfer already created a CRM contact, **When** the job retries, **Then** it reuses the stored CRM contact id instead of creating a duplicate contact
2. **Given** a client has an email match in the CRM but no stored external contact id, **When** the job runs, **Then** it searches by email before creating a new contact and persists the found id
3. **Given** a pending or processing `client_create_sync` transfer already exists for the same client and CRM connection, **When** the same create-sync action is triggered again, **Then** the scheduler returns the existing transfer instead of creating a duplicate
4. **Given** the contact-company association already exists in the CRM, **When** the executor associates them again, **Then** the association is treated as success
5. **Given** the create CRM contact action is accepted from the client page, **When** the request completes, **Then** the user is told the CRM contact creation was queued and can track it in CRM Transfers

---

- What happens when the user has no active CRM connections and a client validates their form? The form validation proceeds normally, but no data transfer occurs. The user is notified that no CRM connection is active.
- What happens when the user disables automatic CRM sync after portal submission? The form validation still completes, but the submission stays local until the user manually exports the linked client from the client page.
- What happens when the CRM provider's API is temporarily unavailable during transfer? The system implements retry logic with 3 retries using exponential backoff (30s, 2min, 10min intervals) and notifies the user if all retry attempts fail.
- What happens when the client data exceeds CRM API limits (e.g., file size too large)? The transfer fails with an appropriate error message, and the user is notified of the specific limitation.
- What happens when OAuth access tokens expire? The system automatically refreshes tokens using refresh tokens. If refresh fails, the user is notified and the connection is marked as requiring re-authorization.
- What happens when the user disconnects a CRM while a transfer is in progress? The transfer completes if already initiated; new transfers are not started for the disconnected CRM. Each CRM transfer is tracked independently.
- What happens when some CRM transfers succeed and others fail? Each CRM transfer is treated independently; success/failure is tracked separately per CRM. Failed transfers are retried independently.
- What happens when a client validates multiple forms in quick succession? Each form validation triggers an independent transfer; the system processes transfers sequentially for all active CRM connections.
- What happens when uploaded files cannot be transferred to CRM (e.g., unsupported file type)? The transfer is recorded as partial success with file-specific errors; user is notified of file failure details. Other data and files are still transferred successfully.
- What happens when the user has multiple clients with the same data (e.g., duplicate company names)? Each client is treated independently; duplicates are not prevented as they may represent different entities.
- What happens when the cleanup process fails to remove data? The system logs the error and retries cleanup on the next scheduled run; data remains until successfully removed.
- What happens when the user clicks "Test Connection" but has no active CRM connections? The button is disabled or hidden; the user is prompted to connect a CRM first.
- What happens when the CRM API returns an error during connection test? The error is categorized (connection, authentication, field mapping, or file upload) and displayed with specific guidance for resolution.
- What happens when a form field cannot be mapped to any CRM field? The field is highlighted with a warning in the mapping preview, and the user is informed that data for this field will not be transferred.
- What happens when test data is sent but the CRM does not support marking records as test data? The test record uses placeholder values that are easily identifiable (e.g., 'Test Client', 'test@example.com') and the user is informed to manually delete the test record.
- What happens when testing multiple CRM connections and some succeed while others fail? The test results summary shows individual status for each CRM with specific error details for failed tests.
- What happens when the user sends test data but the CRM API rate limit is exceeded? The test fails with a rate limit error and the user is informed to retry after the rate limit resets.
- What happens when file upload is tested but the CRM does not support the file type? The test fails with a file type error, and the user is informed which file types are supported.
- What happens when the user modifies form fields after testing the CRM mapping? The mapping preview should be refreshed or the user should be prompted to re-test to verify the new field mappings.
- What happens when OAuth tokens expire during a connection test? The system attempts automatic token refresh; if refresh fails, the test fails with an authentication error and the user is prompted to re-authorize the connection.
- What happens when test data is sent but the CRM creates a duplicate record? The test record is created with unique identifiers (e.g., timestamp) to avoid duplicates, and the user is informed to delete the test record manually.
- What happens when the user edits a CRM-linked client while the linked connection is inactive? The page warns that changes remain local and no automatic CRM update is attempted.
- What happens when the same user opens the linked-client edit page in a different browser or after clearing local storage? The informational modal is shown again because dismissal is browser-local rather than account-global.


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
- **FR-026**: System MUST provide a "Test Connection" button in CRM settings for each connected CRM provider
- **FR-027**: System MUST verify OAuth connection status and API credential validity when testing CRM connection
- **FR-028**: System MUST display categorized error messages (connection, authentication, field mapping, file upload) when CRM tests fail
- **FR-029**: System MUST provide specific guidance for resolving each type of CRM test error
- **FR-030**: System MUST provide a "Test CRM Mapping" feature when creating or editing forms with CRM integration enabled
- **FR-031**: System MUST display a preview of form field to CRM field mappings when testing CRM mapping
- **FR-032**: System MUST highlight form fields that cannot be mapped to CRM fields with appropriate warnings
- **FR-033**: System MUST allow users to send test data to CRM from the form page to verify data transfer
- **FR-034**: System MUST use placeholder/sample data (e.g., 'Test Client', 'test@example.com') when sending test data to CRM
- **FR-035**: System MUST mark test records created in CRM as test data for easy identification and deletion
- **FR-036**: System MUST support testing CRM mapping and data transfer for multiple CRM connections simultaneously
- **FR-037**: System MUST display a summary of test results showing success/failure status for each CRM when testing multiple connections
- **FR-038**: System MUST include test file uploads when verifying CRM data transfer for forms with file fields
- **FR-039**: System MUST allow users to select which CRM(s) to test when multiple connections are active
- **FR-040**: System MUST provide links to view test records in CRM after successful test data transfer
- **FR-041**: System MUST allow users to explicitly configure CRM field mappings for custom form fields within the form builder interface
- **FR-042**: System MUST automatically suggest corresponding CRM properties using fuzzy matching algorithms against form field names
- **FR-043**: System MUST fall back to a "Create as Custom Property" configuration by default when no matching CRM standard property is found
- **FR-044**: System MUST automatically create custom properties in the respective CRMs via their APIs when a payload with "custom property" mappings is dispatched
- **FR-045**: System MUST provide a read-only list in global settings displaying where core application fields (name, company, email) are mapped by default
- **FR-046**: System MUST validate data type compatibility between form fields (text, number, boolean, date, file, json) and CRM property types (string, integer, email, phone, enumeration, datetime, etc.)
- FR-047: System MUST display persistent warnings in the mapping interface if incompatible data types are selected for mapping
- FR-048: System MUST provide an "Export Preview" summary indicating the status ('ready', 'warning', 'none') of Contact and Company record creation per CRM provider
- FR-049: System MUST identify and list missing required identifiers (e.g., 'name' or 'domain' for HubSpot Company) when mapping fields to a CRM object type
- FR-050: System MUST provide an "Auto-Map Fields" feature that uses fuzzy matching and type validation to suggest mappings for form fields efficiently
- FR-051: System MUST perform CRM property lookups and matching asynchronously to avoid blocking the main UI thread (using Svelte 5 $effect and $derived runes)
- FR-052: System MUST allow each user to enable or disable automatic CRM export when a client validates a portal submission
- FR-053: System MUST skip automatic CRM export for validated portal submissions when that user preference is disabled
- FR-054: System MUST keep manual CRM export available from the client page even when automatic portal-submission export is disabled
- FR-055: System MUST display an inline warning on the client edit page when a client is linked to an active CRM connection explaining that CRM fetch is manual and edit-save sync is automatic
- FR-056: System MUST automatically update the linked CRM contact/company record after a successful local save of a CRM-linked client when the linked connection is active
- FR-057: System MUST persist dismissal of the linked-client informational edit modal once per browser/device while continuing to show the inline warning on the page
### Key Entities

- **CRM Connection**: Represents an authorized OAuth2 connection between a user and a CRM provider (Zoho, Salesforce, or HubSpot). Contains connection credentials, status, and provider-specific metadata.
- **Data Transfer**: Represents a single data export operation from the application to a CRM. Contains transfer status, timestamp, CRM provider reference, and list of data items transferred.
- **Transfer Log**: An audit record of all transfer activities including successful transfers, failures, retries, and cleanup operations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-000**: All UI components meet WCAG 2.1 AA accessibility standards (color contrast, keyboard navigation, screen reader compatibility, focus indicators)
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
- **SC-011**: CRM connection test completes within 10 seconds
- **SC-012**: Field mapping preview displays within 5 seconds of clicking "Test CRM Mapping"
- **SC-013**: Test data transfer to CRM completes within 30 seconds for standard test data (excluding large test files)
- **SC-014**: 95% of CRM connection tests provide accurate error categorization (connection, authentication, field mapping, file upload)
- **SC-015**: 90% of users can successfully test their CRM connection and verify field mappings on their first attempt
- **SC-016**: Test records are clearly identifiable in CRM (flagged or using placeholder values) for easy cleanup
- **SC-017**: CRM automatic portal-sync preference changes are persisted and reflected in the settings UI within 3 seconds
- **SC-018**: 100% of successful linked-client edit saves with an active CRM link trigger the linked-profile CRM sync workflow

## Assumptions

- OAuth2 authorization flow follows standard industry practices for each CRM provider
- CRM providers offer APIs that support creating/updating client records and file attachments
- Standard client data fields (name, company, email, phone, address) can be mapped to equivalent fields in all three CRM providers
- File uploads are within reasonable size limits supported by CRM providers (typically under 25MB per file)
- Users have appropriate permissions in their CRM accounts to create and update records
- Data transfer is one-way (application to CRM) and does not require bidirectional synchronization
- The 1-day retention period starts from the timestamp of successful transfer completion
- Cleanup process runs periodically (e.g., hourly) to identify and remove eligible data
- The linked-client informational modal is advisory only, so dismissing it may remain browser-local instead of being synchronized across devices

## Dependencies

- Existing client management functionality (feature 003)
- Existing form management functionality (feature 002)
- Existing client portal and form validation functionality (feature 004)
- Existing file upload functionality (feature 006)
