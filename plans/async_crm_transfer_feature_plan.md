# Async CRM Transfer Feature Plan

> Status: Planning
> Date: 2026-03-19
> Scope: Implement the balanced async CRM transfer approach for client creation and CRM transfer history.
> Delivery style: TDD-first, Rails service boundaries, Inertia-driven UI, Svelte 5 runes.

## 1. Context And Decisions

### 1.1 Product goal

The product goal is to keep client creation fast while making CRM synchronization visible, retryable, and operationally safe.

That means:

- local client creation must complete without waiting for CRM APIs
- CRM failures must be visible after the fact
- the user must be able to retry manually later
- the CRM Transfers page must become the operational history and recovery surface
- the implementation must stay aligned with the existing Rails CRM abstraction layers

### 1.2 Chosen balanced approach

The chosen approach is:

- keep `link` synchronous because it is a local persistence action only
- move `create` during client creation onto the same background transfer pipeline as manual CRM exports
- keep the UI non-blocking during client creation
- use the CRM Transfers page for status, filtering, and manual retry
- defer step-by-step modal progress and per-step retry

This is the best balanced product shape because it keeps the interaction fast, limits architecture churn, and uses the transfer history page as the stable source of truth.

### 1.3 Minimal transfer lifecycle

The minimal lifecycle remains:

1. `pending`
2. `processing`
3. `success`
4. `failed`

This is the smallest status set that satisfies the mandatory criteria:

- the user knows if the transfer is queued, running, successful, or failed
- the user can retry later when it failed
- the state model stays simple enough for Rails jobs and a table-based Inertia UI

### 1.4 Explicitly deferred

The following are intentionally out of scope for the first implementation:

- step-by-step modal progress during client creation
- per-step retry actions
- ActionCable or WebSocket-driven live updates
- large remediation workflows for every failure category
- a rich client dashboard of all transfer history

These are deferred because they add front-end and state complexity before the async backend and retry safety model are fully stable.

### 1.5 TDD rule for this feature

This feature must be implemented with TDD and a strict red-green-refactor loop.

Implementation rule:

1. write or update the failing spec first
2. implement the smallest change needed to make it pass
3. refactor only after the behavior is covered
4. keep controller, service, job, and Svelte page responsibilities narrow

Required testing layers for this feature:

- model specs for transfer lifecycle and filtering
- service specs for transfer scheduling
- job specs for transfer processing and failure handling
- request specs for controller flows and retry actions
- frontend tests for the CRM Transfers page states and filtering

## 2. Architecture Outputs To Produce Before Or During Implementation

### 2.1 Internal architecture document

Complexity: Low

Create a dedicated internal architecture document before the backend refactor settles.

Recommended file:

- `docs/crm_async_transfer_architecture.md`

Purpose:

- document the new transfer lifecycle
- document the scheduler and job responsibilities
- document how client creation now queues async CRM work
- document failure classification, retry behavior, and idempotency considerations
- document why per-step UI is deferred

Contents to include:

- lifecycle states and transitions
- transfer record fields and meaning
- controller to service to job flow
- retry behavior and retry ownership rules
- provider abstraction boundaries
- retention policy linkage

TDD gate:

- do not mark the backend architecture slice complete until the document reflects the implemented structure and naming

### 2.2 Retention and privacy policy output

Complexity: Medium

The feature needs an explicit retention policy for CRM transfer data, and the retention must be reduced to 3 days.

Recommended output split:

1. Internal engineering policy document:
   - `docs/crm_transfer_retention_policy.md`
2. User-facing policy location:
   - add a new privacy policy page and route, because the app currently does not expose an obvious existing privacy-policy page pattern
   - recommended files:
     - `app/controllers/privacy_controller.rb`
     - `app/frontend/pages/Privacy/Show.svelte`
     - route such as `get "privacy", to: "privacy#show"`
   - add the link in the footer

Why this split is recommended:

- engineering needs a precise implementation policy and retention rationale
- users need a clear statement that CRM transfer troubleshooting data is temporary and retained for only 3 days

Policy requirements to document:

- CRM transfer records are operational troubleshooting artifacts
- CRM transfer records are retained for 3 days maximum
- only minimal transfer context should be stored
- `payload_snapshot` must never be exposed to the UI
- retention applies to both successful and failed transfers

TDD gate:

- do not mark retention implementation complete until cleanup behavior is covered by tests and the policy text is written in the chosen locations

## 3. Upgraded Implementation Plan

### Feature 1. Transfer lifecycle foundation

Complexity: Medium

#### Subfeature 1.1 Transfer schema and model

Complexity: Medium

Goals:

- make the transfer record expressive enough for async scheduling, filtering, retry, and retention
- keep the schema small and operational

Tasks:

1. Add or adjust the minimal transfer fields:
   - `status`
   - `trigger`
   - `failure_kind`
   - `attempts_count`
   - `last_attempt_at`
   - `request_context`
   - `transferred_at`
   - keep existing `error_message`, `direction`, and `payload_snapshot`
2. Add status, trigger, and failure-kind constants on `CrmTransfer`
3. Add scopes for:
   - newest first
   - filter by status
   - filter by provider
   - filter by trigger
   - retryable transfers
   - retention cutoff older than 3 days
4. Keep `status` as strings rather than converting to framework enums if that stays more consistent with the existing codebase

Subtasks:

- keep `request_context` minimal to limit stored sensitive information
- do not add `user_id` unless a later query-performance need makes it necessary
- treat `payload_snapshot` as temporary operational data only

TDD tasks:

1. Add failing model specs for:
   - allowed statuses and triggers
   - retryable scope
   - filtering scopes
   - retention cutoff scope
2. Add or update factories for transfer states and triggers

#### Subfeature 1.2 Transfer serialization for Inertia

Complexity: Low

Goals:

- give the history page a stable, UI-safe transfer shape

Tasks:

1. Add a serializer or presenter for CRM transfers
2. Expose only:
   - id
   - created_at
   - client summary
   - provider
   - status
   - trigger
   - failure_kind
   - error message
   - attempts count
   - transferred_at
   - retryable flag
3. Do not expose `payload_snapshot` or raw request context to the page

TDD tasks:

1. Add failing serializer or request-level expectations proving the UI payload is minimal

### Feature 2. Unified async transfer architecture

Complexity: High

#### Subfeature 2.1 Scheduling boundary

Complexity: Medium

Goals:

- create one place responsible for creating transfer rows and enqueueing work
- stop scattering transfer-row creation across different flows

Tasks:

1. Add `Crm::TransferScheduler`
2. Make `Crm::DataExporter` delegate transfer creation and enqueueing to the scheduler
3. Accept:
   - `client`
   - `connection`
   - `trigger`
   - `request_context`
4. Centralize defaults:
   - `status: pending`
   - `attempts_count: 0`
   - `direction: export`

Subtasks:

- keep scheduling logic out of controllers
- keep provider-specific behavior out of the scheduler

TDD tasks:

1. Add failing service specs for scheduler behavior
2. Assert that scheduling creates the right transfer row and enqueues the job

#### Subfeature 2.2 Transfer processing job

Complexity: High

Goals:

- process all async CRM transfer types through one transfer-oriented job path

Tasks:

1. Generalize the current export job around the transfer record
2. Mark the transfer `processing` when execution starts
3. Increment `attempts_count` and set `last_attempt_at`
4. Dispatch behavior by `trigger`
5. On success:
   - set `success`
   - set `transferred_at`
   - clear error state if appropriate
6. On failure:
   - classify `failure_kind`
   - set `failed`
   - persist a user-facing error message

Subtasks:

- keep the job orchestration-focused
- continue delegating provider API work to CRM services
- preserve retry and discard rules already in place where still valid

TDD tasks:

1. Add failing job specs for:
   - pending to processing to success
   - pending to processing to failed
   - failure classification
   - retry bookkeeping

#### Subfeature 2.3 Detailed architecture write-up

Complexity: Low

Goals:

- document the architecture while it is still fresh and implementation decisions are explicit

Tasks:

1. Create `docs/crm_async_transfer_architecture.md`
2. Write the implemented transfer flow in detail:
   - client creation path
   - manual export path
   - transfer scheduler
   - transfer job
   - retry path
   - provider boundary expectations
3. Include rationale for the minimal lifecycle and deferred items

TDD tasks:

1. Add this as a completion requirement in the slice checklist
2. Review the document against the final code before closing the slice

### Feature 3. Refactor client creation to use the transfer pipeline

Complexity: High

#### Subfeature 3.1 Keep local client creation fast

Complexity: Medium

Goals:

- preserve the existing local save and invitation flow
- remove third-party CRM latency from the request path

Tasks:

1. Keep `ClientsController#create` focused on local persistence and invitation logic
2. Interpret CRM strategy after local save:
   - `skip`: no CRM work
   - `link`: persist `CrmClientLink` synchronously
   - `create`: enqueue a `client_create_sync` transfer through the scheduler
3. Keep the Inertia redirect behavior unchanged

Subtasks:

- do not let the controller call provider services directly
- keep `link` synchronous because it does not call the CRM

TDD tasks:

1. Add failing request specs for client creation covering:
   - skip path
   - link path
   - create path queuing a transfer instead of calling remote CRM services synchronously
2. Add failing integration-level specs proving the local client create succeeds even when async CRM work is queued

#### Subfeature 3.2 Safe async `client_create_sync` processing

Complexity: High

Goals:

- create the contact and company asynchronously without introducing unnecessary duplicates

Tasks:

1. Process `client_create_sync` transfers in the job
2. Use minimal request context, including options such as `sync_address_to_contact`
3. Persist `CrmClientLink` as soon as external ids are known
4. Reuse provider search-before-create behavior where available
5. Associate contact and company only when both ids are available

Subtasks:

- persist contact id as early as possible after successful remote contact creation
- persist company id as early as possible after successful find-or-create behavior
- keep idempotency risk documented in the architecture file

TDD tasks:

1. Add failing job and service specs for:
   - contact created only
   - contact and company created and linked
   - provider error leading to failed transfer without blocking local client creation

#### Subfeature 3.3 Post-create UX message

Complexity: Low

Goals:

- make the async behavior obvious without blocking the user

Tasks:

1. Add a notice or banner after client creation when a CRM transfer was queued
2. Link users toward the CRM Transfers page for monitoring and retry

Subtasks:

- keep the copy short
- do not show a loading modal during client creation

TDD tasks:

1. Add request or UI expectations for the queued notice behavior

### Feature 4. Real CRM Transfers page with retry and filters

Complexity: High

#### Subfeature 4.1 Real index endpoint

Complexity: Medium

Goals:

- replace the dummy controller with a real operational history endpoint

Tasks:

1. Replace the dummy `index` action with a real query-backed page
2. Scope transfers to the current user through owned clients and connections
3. Support server-side filters:
   - status
   - provider
   - trigger
4. Paginate results
5. Default the page to transfers from the last 3 days

Subtasks:

- sort newest first
- keep filtering server-side instead of client-only

TDD tasks:

1. Add failing request specs for:
   - index visibility limited to current user
   - status filter
   - provider filter
   - trigger filter
   - 3-day default window

#### Subfeature 4.2 Real Inertia page

Complexity: Medium

Goals:

- convert the CRM Transfers page from dummy content to a real operational tool

Tasks:

1. Replace dummy transfer rows with Inertia props
2. Add filter controls bound to query params
3. Add empty states for:
   - no transfers yet
   - no matches for current filters
4. Render clear states for:
   - pending
   - processing
   - success
   - failed
5. Add retry buttons for retryable failed transfers

Subtasks:

- keep the page table-first and operational
- use Svelte 5 runes for local UI state if needed
- stay aligned with Inertia navigation instead of building a fetch-heavy custom client

TDD tasks:

1. Add failing frontend tests for:
   - empty state
   - filtered list rendering
   - failed row showing retry
   - processing and pending states

#### Subfeature 4.3 Retry endpoint

Complexity: Medium

Goals:

- let the user manually retry a failed transfer later

Tasks:

1. Add a retry route such as `POST /crm_transfers/:id/retry`
2. Restrict retries to failed transfers owned by the current user
3. Implement retry by creating a new transfer row with the minimal original context
4. Redirect back with a notice or refreshed history state

Subtasks:

- do not mutate the failed row into a new attempt
- preserve failure history by creating a fresh row

TDD tasks:

1. Add failing request specs for:
   - retry success
   - unauthorized retry rejection
   - retry only allowed for failed transfers

### Feature 5. Retention and privacy policy

Complexity: Medium

#### Subfeature 5.1 Three-day cleanup implementation

Complexity: Low

Goals:

- enforce a short-lived retention window for CRM transfer artifacts

Tasks:

1. Add a cleanup job that deletes transfers older than 3 days
2. Schedule it to run automatically through the app’s recurring job mechanism
3. Apply the same retention rule to both successful and failed transfers

Subtasks:

- keep the retention rule centralized and testable
- ensure the transfer index default window matches the same 3-day mental model

TDD tasks:

1. Add failing job specs for cleanup behavior
2. Add failing request or model-level expectations for the 3-day cutoff scope

#### Subfeature 5.2 Internal retention policy document

Complexity: Low

Goals:

- document why the data is retained, what is retained, and for how long

Tasks:

1. Create `docs/crm_transfer_retention_policy.md`
2. Document:
   - retention duration of 3 days
   - allowed stored fields
   - why transfer data is temporary troubleshooting data
   - why payload data is not exposed in the UI
   - cleanup ownership and operational expectations

TDD tasks:

1. Add this document as a checklist item for closing the retention slice

#### Subfeature 5.3 User-facing privacy policy disclosure

Complexity: Medium

Goals:

- expose the retention rule in a place users can actually read

Tasks:

1. Add a basic privacy policy page because the app currently has no obvious existing privacy-policy page pattern
2. Recommended Rails/Inertia structure:
   - `PrivacyController#show`
   - route at `/privacy`
   - `app/frontend/pages/Privacy/Show.svelte`
3. Include a short section describing temporary CRM transfer data retention for 3 days

Subtasks:

- keep the page simple and static in the first iteration
- align the wording with the internal retention policy document

TDD tasks:

1. Add request coverage for the privacy page route
2. Add a lightweight frontend rendering test if the project’s page-test coverage makes that worthwhile

### Feature 6. Delivery discipline and best practices

Complexity: Medium

#### Subfeature 6.1 Best-practice execution rules

Complexity: Low

Rules to enforce during implementation:

- thin controllers, orchestration in services and jobs
- provider-specific behavior remains behind CRM service abstractions
- no business logic in Svelte pages beyond presentation and Inertia interactions
- no direct ad hoc fetch flows when an Inertia action is sufficient
- no large client-side state machine for this feature
- no exposure of raw payload snapshots to the frontend

#### Subfeature 6.2 TDD delivery order

Complexity: Medium

Implementation order:

1. write failing model and factory coverage for the transfer lifecycle
2. write failing scheduler and job specs
3. implement the scheduler and job refactor
4. write failing request specs for client create async behavior
5. refactor `ClientsController#create`
6. write failing request specs for transfer index and retry
7. implement controller and query layer
8. write failing frontend tests for the real CRM Transfers page
9. implement the Svelte page
10. write failing cleanup specs and implement 3-day retention job
11. write and review the architecture and policy documents

## 4. Complexity Summary

| Feature | Complexity | Reason |
|---|---|---|
| Transfer lifecycle foundation | Medium | Small schema changes plus filtering and serialization |
| Unified async transfer architecture | High | Requires refactoring scheduling and job responsibilities cleanly |
| Client creation async refactor | High | Must preserve fast local create flow while safely queuing CRM work |
| Real CRM Transfers page | High | Requires controller, filtering, retry, and page rewrite |
| Retention and privacy policy | Medium | Cleanup is simple, but policy output requires both internal and user-facing documentation |
| Delivery discipline and TDD | Medium | Straightforward in concept, but must be enforced across backend and frontend work |

## 5. Final Delivery Order

Build the feature in this order:

1. Transfer lifecycle schema, model, and tests
2. Transfer scheduler and generalized job refactor with tests
3. Client create async refactor with tests
4. Detailed async CRM architecture document
5. Real CRM Transfers page, filters, and retry with tests
6. Three-day retention cleanup with tests
7. Internal retention policy document and user-facing privacy policy page

## 6. Completion Criteria

The feature is complete only when all of the following are true:

- client creation no longer waits on remote CRM create operations
- manual export and client-create CRM sync both use the same transfer/job architecture
- the CRM Transfers page shows real transfer records with filtering and retry
- failed transfers can be retried manually through a new transfer row
- CRM transfer retention is enforced at 3 days
- the async architecture is documented in `docs/crm_async_transfer_architecture.md`
- the retention policy is documented internally and disclosed through a privacy policy page
- backend and frontend changes were delivered with tests written first and passing