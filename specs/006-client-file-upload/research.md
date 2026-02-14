# Research: Client File Upload — Phase 0

Feature: Client File Upload System (branch: 006-client-file-upload)

Decision: Use Rails Active Storage with Amazon S3 (private buckets) and presigned URLs for uploads/downloads.

Rationale:
- Active Storage is already referenced in the spec and integrates with Rails models and direct uploads from the browser.
- S3 provides durable, scalable private storage with presigned URL support and lifecycle controls.
- Using presigned URLs allows the app to avoid proxying large file payloads while preserving access control on download via short-lived URLs.

Specifics taken from the specification:
- Signed URL expiry for downloads: 5 minutes (NFR-003 / spec clarification).
- File naming in storage: UUID-based keys with original filename preserved for display.
- Files must be destroyed on user download (mark as deleted + async purge) and when the associated client is deleted.
- Audit logging for upload/download/delete activities with 90-day retention.

Alternatives considered:
- Proxy uploads through the Rails app (rejected: increases load and memory usage)
- Use a third-party file service (Filestack, Cloudinary) (rejected: additional cost and integration complexity)

---

Decision: Enforce AES-256 encryption at rest using provider-managed keys (AWS KMS) and store only encrypted blobs in S3.

Rationale:
- Meets NFR-001/NFR-002. AWS S3 + KMS provides managed key rotation and simplifies compliance.

Alternatives considered:
- Application-managed encryption keys (rejected: complexity and key management burden)

---

Decision: Validate files by MIME type and magic bytes server-side, with client-side extension and size checks.

Rationale:
- Prevents simple spoofing of content type and reduces risk of storing malicious payloads.
- Magic-bytes validation provides stronger assurance than extension-only checks.

Alternatives considered:
- Full malware scanning (out of scope for initial implementation)

---

Decision: Max file size 10MB; enforce limits both client and server side. Implement auto-retry once with exponential backoff on transient failures.

Rationale:
- Matches feature spec requirement (FR-004, FR-018) and keeps uploads within reasonable resource usage.

Specifics:
- Auto-retry parameters: 2 seconds initial delay, doubling to 4 seconds (spec clarification).

Alternatives considered:
- Increase limit for large files (rejected: out of scope)

---

Decision: Download flow will generate a short-lived signed URL and, after successful download is confirmed by the app, delete the file (as required by spec). Implementation will mark file as deleted and asynchronously purge the blob to avoid blocking the response path.

Rationale:
- Preserves private storage, issuance of expiring URLs (NFR-003), and supports the requirement to destroy files after download. Using asynchronous deletion improves UX and reliability.

Alternatives considered:
- Immediate synchronous deletion (rejected: increases risk of failed download if deletion occurs too early)

---

Decision: Frontend UX: use Active Storage Direct Uploads (or a small custom Svelte uploader) with progress events to satisfy FR-005 and accessibility requirements (WCAG 2.1 AA).

Rationale:
- Active Storage direct uploads provide progress events and integrate cleanly with Rails UJS or a Svelte wrapper.
- Progress updates should be visible within 1 second of upload initiation (NFR-007 / SC-005).

Alternatives considered:
- Chunked multipart upload (only if large files or resume support required; not needed for 10MB limit)

---

Decision: Rate limiting at 10 uploads per client per minute enforced at controller level (Rack Attack or API gateway) with clear 429 responses.

Rationale:
- Matches spec and prevents abuse.

Alternatives considered:
- IP-based throttling (rejected: multi-tenant clients behind same NAT would be impacted)


Resolved Unknowns (all NEEDS CLARIFICATION from template resolved):
- Storage provider: Amazon S3
- Encryption: AES-256 via AWS KMS
- Validation depth: MIME type + magic bytes
- Max size: 10MB
- Rate limiting: 10 uploads/client/min
- Download deletion semantics: mark as deleted and async purge after confirmed download
- Signed URL expiry: 5 minutes
- Auto-retry/backoff: 2s -> 4s
- Audit log retention: 90 days
- File naming: UUID keys with original filename preserved for display
- Accessibility: WCAG 2.1 Level AA


Artifacts referenced (absolute paths):
- Implementation plan: /home/a/Documents/Projets/quick-kyb/quick-kyb/specs/006-client-file-upload/plan.md
- This research: /home/a/Documents/Projets/quick-kyb/quick-kyb/specs/006-client-file-upload/research.md
