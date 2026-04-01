# CRM Transfer Retention Policy

## Purpose

CRM transfer rows are retained only long enough to support troubleshooting, delivery verification, and manual retry.

## Retention Window

- Maximum retention: 3 days
- Applies to successful transfers
- Applies to failed transfers
- Older rows are deleted automatically by scheduled cleanup

## Data Kept During Retention

The operational record may include:

- transfer timestamps
- provider and trigger
- status and failure category
- retry counters
- minimal request context required to re-run the transfer
- temporary payload snapshot used internally by background processing

## UI Exposure Rules

The CRM Transfers page must not expose:

- `payload_snapshot`
- raw `request_context`

Only user-safe summary data is serialized to Inertia.

## Rationale

Transfer rows are not a system-of-record for customer data. They are temporary troubleshooting artifacts. Limiting retention reduces the amount of operational export context stored inside the application while preserving a short window for investigation and retry.

## Enforcement

`CrmTransferCleanupJob` removes transfer rows older than the retention cutoff.