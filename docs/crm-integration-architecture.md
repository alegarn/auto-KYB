# CRM Integration Architecture

## Overview

The CRM Integration feature allows users to connect their Quick KYB account to external CRM providers (HubSpot, Salesforce, Zoho) via OAuth2. Once connected, client data and uploaded files can be automatically or manually exported to these CRMs.

This document outlines the architecture of the Phase 1 implementation, which establishes the UI foundation (using dummy data) and the backend abstraction layer.

## Architecture & Design Decisions

To ensure the system is scalable and maintainable, we implemented a **Service Object / Strategy Pattern** for the backend. This prevents the core `Client` and `User` models from becoming bloated with CRM-specific API logic.

### Database Schema

Two new models were introduced:

1. **`CrmConnection`**: Stores the OAuth credentials and connection status for a user.
   - `user_id` (Reference)
   - `provider` (String: 'hubspot', 'salesforce', 'zoho')
   - `access_token` (String)
   - `refresh_token` (String)
   - `expires_at` (Datetime)
   - `status` (String: 'active', 'disconnected')

2. **`CrmTransfer`**: Acts as an audit log and state tracker for data exports.
   - `client_id` (Reference)
   - `crm_connection_id` (Reference)
   - `status` (String: 'pending', 'success', 'failed')
   - `error_message` (Text)
   - `transferred_at` (Datetime)

### Backend Abstraction Layer (`app/services/crm/`)

The backend logic is encapsulated in the `Crm` namespace:

- **`Crm::BaseService`**: An abstract base class defining the contract that all CRM providers must fulfill (`authorize_url`, `exchange_token`, `refresh_token!`, `export_data`, `test_connection`).
- **Provider Services** (`HubspotService`, `SalesforceService`, `ZohoService`): Concrete implementations of the `BaseService`. *(Note: In Phase 1, these contain dummy implementations).*
- **`Crm::ConnectionManager`**: A factory class responsible for instantiating the correct provider service based on a `CrmConnection` record.
- **`Crm::DataExporter`**: Orchestrates the export process. It finds all active connections for a user, creates pending `CrmTransfer` records, and enqueues background jobs.

### Background Processing

Data exports are handled asynchronously to prevent blocking web requests and to handle API rate limits gracefully.

- **`CrmDataExportJob`**: An `ActiveJob` that takes a `transfer_id`. It fetches the appropriate service via the `ConnectionManager` and attempts the export.
- **Retry Logic**: The job implements exponential backoff (`retry_on StandardError, wait: :exponentially_longer, attempts: 3`). If a transfer fails, the `CrmTransfer` record is updated with the error message.

## Frontend Implementation (Svelte 5)

The UI was built using Svelte 5 runes (`$state`, `$derived`) and Inertia.js, utilizing the existing `shadcn-svelte` component library.

### Key Components & Pages

1. **Settings Page (`app/frontend/pages/Settings/Index.svelte`)**:
   - Added a "CRM Integrations" card.
   - Displays available CRMs with Connect/Disconnect/Test buttons.
   - *Phase 1 Status*: Uses dummy `$state` to simulate network latency and connection toggling.

2. **Client Details Page (`app/frontend/pages/Clients/Show.svelte`)**:
   - Added an "Export to CRM" button.
   - Opens a `Modal` allowing the user to select specific active CRMs for manual export.

3. **Transfer History (`app/frontend/pages/CrmTransfers/Index.svelte`)**:
   - A new page accessible via the main sidebar.
   - Displays a `Table` of past transfers, showing the date, client, CRM provider, and status (Success, Pending, Failed).

4. **Form Builder (`app/frontend/pages/forms/edit.svelte`)**:
   - Added a "Test CRM Mapping" feature.
   - Opens a `Modal` showing how form fields map to CRM export keys, allowing users to verify their configuration before sending real data.

## Data Flow Lifecycle

1. **Authorization**: User clicks "Connect" -> Redirected to CRM OAuth page -> Returns to app -> `CrmConnection` created.
2. **Trigger**: Client validates a form (Automatic) OR User clicks "Export" (Manual).
3. **Orchestration**: `Crm::DataExporter` creates a `CrmTransfer` (status: pending) for each active connection and enqueues `CrmDataExportJob`.
4. **Execution**: `CrmDataExportJob` runs -> Calls `export_data` on the specific provider service.
5. **Result**: `CrmTransfer` is updated to `success` or `failed`. If failed, the job retries up to 3 times.

## How to Add a New CRM Provider

To add a new CRM (e.g., Pipedrive) in the future:

1. Create `app/services/crm/pipedrive_service.rb` inheriting from `Crm::BaseService`.
2. Implement the required methods (`authorize_url`, `exchange_token`, `export_data`, etc.).
3. Update `Crm::ConnectionManager.service_for` to return `PipedriveService` when `provider == 'pipedrive'`.
4. Add the provider to the UI list in `Settings/Index.svelte` and `Clients/Show.svelte`.

## Testing Strategy

- **Backend**: RSpec is used for models, services, and jobs. Factories are defined in `spec/factories/`. External API calls in the services should be mocked using WebMock or VCR in subsequent phases.
- **Frontend**: Vitest and `@testing-library/svelte` are used to verify UI rendering and user interactions. Inertia routing is mocked to isolate component tests.

## Known Limitations (Phase 1)

- The OAuth flow and API data exports are currently stubbed with dummy data in the services.
- The UI state for CRM connections is local to the Svelte components and does not yet persist to the backend controllers.
- Phase 2 will involve wiring the Svelte UI to the Rails controllers and implementing the actual HTTP requests to the HubSpot, Salesforce, and Zoho APIs.