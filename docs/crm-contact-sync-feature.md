# CRM Contact Sync Feature

## 1. Overview
The CRM Contact Sync feature resolves previous issues with data integrity, duplication, and user friction by shifting CRM contact creation from an implicit, automatic background process to a deliberate, user-driven action. It ensures that developers and users have complete control over how clients in Quick KYB map to external CRM contacts (such as HubSpot).

This document outlines the structural architecture and operational flows of the feature.

## 2. Architectural Paradigm Shift
Previously, exporting data to the CRM would implicitly attempt to `upsert` (create or update) contacts. This caused latency, brittle transactions, and opaque duplicate handling.

**New Paradigm:**
* **Explicit Intent:** CRM contacts are created or linked *before* any payload data is exported.
* **Separation of Concerns:** The `export_data` pipeline assumes a CRM link exists. If it does not, the export safely aborts or skips the CRM step rather than guessing.
* **Asynchronous UX:** CRM API calls (which are historically slow) are removed from the critical rendering path of the application.

## 3. Structural Components

### A. Data Architecture
To avoid bloating the core `Client` table and to support a multi-CRM future, CRM associations are handled via a dedicated linking model (e.g., `CrmLink` or `CrmMapping`).

* **Attributes:** `client_id`, `crm_connection_id`, `external_contact_id`, `external_company_id`.
* **Behavior:** Rails strictly looks for this associated record before interacting with the CRM.

### B. Integration Services (`HubspotService`)
The CRM service classes have been refactored to use a modular mapping architecture:
* **Multi-CRM Modularity**: Mapping logic is decoupled from base services. Specific CRM logic resides in `Crm::[Provider]::FieldMapper` (e.g., [app/services/crm/hubspot/field_mapper.rb](app/services/crm/hubspot/field_mapper.rb)).
* **Base Abstraction**: `Crm::FieldMapper` provides shared utilities (like name splitting) while delegating vendor-specific field translations to specialized mappers.
* `create_contact(client)`: Directly creates a new contact in the CRM based on the Quick KYB client.
* `link_existing_contact(client, external_id)`: Saves an external CRM ID to the local database mapping.
* `update_existing_contact(external_id, data)`: Pushes new form data to an already established CRM contact.

The primary `export_data(client, data, files)` method now acts as a guard:
```ruby
def export_data(client, data, files = [])
  external_id = client.crm_link&.external_contact_id
  return { success: false, error: "Client not linked to CRM" } unless external_id

  update_existing_contact(external_id, data)
  # ... export files and other artifacts
end
```

## 4. Operational Flows

### A. Client Creation Flow
When a user creates a new client (`Clients/New.svelte`), they are prompted with a sync strategy selector:
1. **Do not connect to CRM:** Bypasses CRM logic completely.
2. **Fetch existing contact:** Queries the CRM (e.g., `GET /crm/search?email=...`) and allows the user to select an existing record to link.
3. **Create new contact in CRM:** Submits the client to the local database, and kicks off an asynchronous job to push the base contact details to the CRM, subsequently saving the returned `external_id`.

*Crucially, the CRM API call is decoupled from the transaction that saves the `Client` to the database, ensuring that transient API errors do not block local user onboarding.*

### B. Client Edit Flow (Deferred Search)
When a user edits a client that is **not** currently linked to a CRM, the page employs a deferred loading UX pattern to maintain instant rendering speeds:
1. The Svelte application renders the `Clients/Edit.svelte` view immediately using Inertia.
2. On mount, an asynchronous fetch is made to a dedicated Rails endpoint: `GET /clients/:id/crm_match_suggestions`.
3. If an existing match is found in the CRM (usually matched via email), a **CRM Match Banner** slides into view.
4. The banner offers actionable buttons: `[Link this Contact]`, `[Create as New Contact]`, or `[Dismiss]`.

### C. Data Export Flow
Once a link is established, standard operations like "Export to CRM" proceed safely. The system passes the locally stored `external_contact_id` to the CRM API, updating fields without risking duplication.

## 5. Technical Implementation Notes

### Svelte 5 & Inertia
* UI states for the Match Banner and Sync Strategy utilize Svelte 5 `$state` runes for reactive DOM updates.
* To avoid UI thread blocking, CRM matches are never fetched via Inertia's blocking synchronous props from the standard `edit` controller action. They rely on asynchronous `fetch()` requests triggered Post-Mount.

### Rails Controllers
* Endpoints like `crm_match_suggestions` and `link_crm_contact` are exposed specifically for XHR/Fetch consumption, returning strict JSON payloads to the frontend.
* Strong parameter enforcement and `rescue_from` blocks are implemented on all CRM-touching endpoints to catch timeouts and rate limits gracefully.
