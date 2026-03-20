# CRM Async Transfer Architecture

## Scope

This document describes the operational CRM transfer surface used for asynchronous export history, filtering, retry, and retention.

## Transfer Lifecycle

CRM transfer rows move through a small lifecycle:

- `pending`: queued but not started
- `processing`: actively running in a background job
- `success`: provider export completed
- `failed`: provider export failed and may be retryable depending on `failure_kind`

`CrmTransfer` also stores:

- `trigger`: why the transfer was created
- `failure_kind`: normalized failure category
- `attempts_count`: number of job executions
- `last_attempt_at`: timestamp of the latest execution attempt
- `request_context`: minimal internal context used by the job
- `payload_snapshot`: temporary internal export snapshot for troubleshooting

## Scheduling Boundary

`Crm::DataExporter` delegates row creation and job enqueueing to `Crm::TransferScheduler`.

Responsibilities are split as follows:

- `Crm::DataExporter`: chooses which active connections should receive an export
- `Crm::TransferScheduler`: creates the transfer row with lifecycle defaults and enqueues `CrmDataExportJob`
- `CrmDataExportJob`: performs provider work and updates lifecycle state

Retry uses the same scheduler boundary. A retry never mutates the failed row into a new attempt record. Instead, a fresh pending transfer row is created from the original transfer's client, connection, trigger, and minimal retry context.

## Index Query Surface

The CRM Transfers page is backed by `CrmTransfersController#index`.

Operational rules:

- scope transfers to the current user's clients and CRM connections
- order newest first
- default to the last 3 days of transfer history
- apply server-side filters for `status`, `provider`, and `trigger`
- paginate results with Pagy

Only UI-safe fields are serialized for Inertia. `payload_snapshot` and raw `request_context` are intentionally excluded from the page payload.

## Retry Rules

`POST /crm_transfers/:id/retry` enforces the following:

- the transfer must belong to the current user
- the transfer must be `failed`
- the failure must be retryable based on `CrmTransfer::RETRYABLE_FAILURE_KINDS`

If the row is eligible, the endpoint schedules a new transfer row through `Crm::TransferScheduler.retry!` and redirects back to the history page.

## Retention

CRM transfer rows are short-lived operational records.

- retention period: 3 days
- applies to successful and failed transfers
- enforced by `CrmTransferCleanupJob`
- history page uses the same 3-day window as its default view

This keeps enough history for operational review and retry while limiting the persistence of temporary export artifacts.

## Deferred Areas

This slice does not expand the client-create sync trigger implementation. The operational surface is intentionally limited to history, retry mechanics, and retention behavior that are shared by transfer rows already flowing through the existing scheduler and export job.