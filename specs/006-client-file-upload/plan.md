# Implementation Plan: Client File Upload System

**Branch**: `006-client-file-upload` | **Date**: 2026-02-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-client-file-upload/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

The Client File Upload System enables clients to upload files (PDF, JPEG, PNG) to form fields designated for file uploads, and allows users to download these files from the client's show page. The technical approach uses Rails Active Storage with Amazon S3 (private buckets) and presigned URLs for uploads/downloads. Files are encrypted at rest using AES-256 encryption via AWS KMS, with automatic deletion after user download or client deletion. The system includes comprehensive validation (MIME type + magic bytes), rate limiting (10 uploads per client per minute), and auto-retry logic for failed uploads.

## Technical Context

**Language/Version**: Ruby 3.x, Ruby on Rails 8.1
**Primary Dependencies**: Active Storage (Rails built-in), Inertia.js, Svelte 5 (frontend), PostgreSQL, RSpec (testing)
**Storage**: PostgreSQL (primary persistent store), Amazon S3 (file storage via Active Storage)
**Testing**: RSpec (unit/integration/system tests), Capybara (system tests)
**Target Platform**: Web application (Linux server)
**Project Type**: Web (Rails backend + Svelte frontend)
**Performance Goals**:
- File upload progress updates within 1 second of initiation
- Invalid file type errors displayed within 2 seconds of selection
- 5MB file uploads complete within 30 seconds on standard broadband
- File downloads complete within 5 seconds on standard broadband
- Support concurrent uploads from at least 50 clients with 5MB average file size
**Constraints**:
- Maximum file size: 10MB per upload
- Signed URL expiration: 5 minutes for downloads
- Rate limiting: 10 uploads per client per minute
- WCAG 2.1 Level AA accessibility compliance
**Scale/Scope**: Single web application with client portal and user admin interface

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Code Quality (Principle I)
- [x] Code follows Ruby on Rails community standards
- [x] Code passes RuboCop linting with project-specific rules
- [x] Code is self-documenting with clear variable and method names
- [x] Complex logic is extracted into well-named methods or service objects
- [x] Public methods have documentation comments

### DRY (Principle II)
- [x] Code duplication is eliminated through proper abstraction
- [x] Common functionality is extracted into shared modules, concerns, or service objects
- [x] Views use partials and components for repeated UI patterns
- [x] Database queries are scoped and reused

### Convention Over Configuration (Principle III)
- [x] Ruby on Rails conventions for naming, file structure, and patterns are followed
- [x] Custom configurations are only used when conventions cannot meet requirements
- [x] Rails generators and standard directory structure are used
- [x] RESTful routing conventions are followed

### MVC Architecture (Principle IV)
- [x] Models contain business logic and data access rules
- [x] Controllers are thin, handling only request/response orchestration
- [x] Views are presentation logic only, with no business logic
- [x] Cross-cutting concerns use concerns, services, or decorators appropriately

### RESTful Design (Principle V)
- [x] API endpoints follow RESTful conventions with appropriate HTTP verbs
- [x] Resources are nouns and actions are verbs
- [x] Standard Rails resource routing is used
- [x] Responses have appropriate status codes
- [x] API is stateless with proper HTTP caching headers

### Test-Driven Development (Principle VI) - NON-NEGOTIABLE
- [x] Tests are written before implementation code (Red-Green-Refactor cycle)
- [x] All features have corresponding tests
- [x] Tests cover happy paths, edge cases, and error conditions
- [x] Test suite runs quickly and reliably
- [x] Integration tests cover critical user journeys
- [x] Unit tests cover business logic

### Quality Standards
- [x] User interfaces follow consistent design patterns and components
- [x] Shared Svelte components from `app/frontend/components/ui/` are used
- [x] Consistent color schemes, typography, and spacing are maintained
- [x] User-facing text is clear, concise, and uses consistent terminology
- [x] Loading states and error messages are consistent
- [x] UI is responsive and works across device sizes
- [x] Accessibility compliance (WCAG 2.1 AA minimum) is ensured

### Performance Requirements
- [x] API endpoints respond within 200ms (p95) for standard operations
- [x] Page loads complete within 2 seconds on 3G connections
- [x] Database queries are optimized with proper indexing
- [x] N+1 queries are eliminated through eager loading
- [x] Frontend bundle size is optimized through code splitting
- [x] Images and assets are optimized and lazy-loaded
- [x] Appropriate caching is implemented at multiple levels

## Project Structure

### Documentation (this feature)

```text
specs/006-client-file-upload/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── uploaded_file.rb          # ActiveRecord model wrapping Active Storage (business fields only)
│   └── form_response.rb          # (existing) add has_many :uploaded_files
├── controllers/
│   ├── client_portal/
│   │   ├── form_responses_controller.rb  # (existing) client form submission
│   │   └── uploaded_files_controller.rb  # Client upload endpoint (POST)
│   └── uploaded_files_controller.rb      # User download/delete endpoints (authenticated)
├── services/
│   ├── file_upload_service.rb    # Upload logic with validation
│   ├── file_download_service.rb  # Download logic with deletion
│   └── file_validation_service.rb # MIME/magic bytes validation
├── jobs/
│   └── purge_file_job.rb         # Async file purging background job
└── frontend/
    ├── components/
    │   └── file_upload/
    │       ├── FileUploader.svelte      # Main upload component
    │       ├── UploadProgress.svelte    # Progress indicator
    │       └── FilePreview.svelte       # File preview after upload
    └── pages/
        ├── ClientPortal/
        │   └── FormResponse.svelte      # (existing) client form with file uploads
        └── Clients/
            └── Show.svelte              # (existing) user view with file downloads

spec/
├── models/
│   └── uploaded_file_spec.rb
├── controllers/
│   ├── client_portal/
│   │   └── uploaded_files_controller_spec.rb
│   └── uploaded_files_controller_spec.rb
├── services/
│   ├── file_upload_service_spec.rb
│   ├── file_download_service_spec.rb
│   └── file_validation_service_spec.rb
├── jobs/
│   └── purge_file_job_spec.rb
└── system/
    └── client_file_upload_spec.rb

db/
└── migrate/
    └── 20260213000000_create_uploaded_files.rb
```

**Structure Decision**: Follows the existing Inertia-based architecture. Client uploads go through the `client_portal` namespace (which already handles client authentication via access token/cookie). User downloads/deletions go through a root-level controller (which uses standard user authentication). No API namespace is needed -- this app is not an API; all controllers render Inertia pages or redirect. Tests use RSpec under `spec/` consistent with the rest of the project.

## Edge Cases

This section documents all edge cases identified in the specification and their planned handling strategies.

### 1. Duplicate File Names

**Edge Case**: What happens when a client tries to upload a file with the same name as an existing file?

**Handling Strategy**:
- System generates a unique identifier (UUID) for each uploaded file
- Original filename is preserved for display purposes only
- Storage key is UUID-based, preventing any naming conflicts
- Multiple files with the same name can coexist in the system
- Implementation: Active Storage automatically generates unique storage keys

**Test Scenario**: Given a client has uploaded a file named "document.pdf", when the client uploads another file also named "document.pdf" to a different field or response, then both files are stored successfully and can be accessed independently.

---

### 2. Network Interruptions During Upload

**Edge Case**: How does the system handle network interruptions during file upload?

**Handling Strategy**:
- Auto-retry once with exponential backoff (2 seconds initial delay, doubling to 4 seconds)
- After failed retry, display clear error message to the client
- Client must manually retry the upload
- Progress indicator shows current status (uploading, retrying, failed)
- Implementation: Use Active Storage's built-in retry mechanism or custom retry logic in the upload service

**Test Scenarios**:
- Given a client is uploading a file, when the network connection is interrupted during upload, then the system automatically retries once and displays appropriate status
- Given a client is uploading a file, when both the initial upload and retry fail, then the system displays an error message and requires manual retry by the client

---

### 3. Missing Required Files on Form Submission

**Edge Case**: What happens when a client submits a form without uploading required files?

**Handling Strategy**:
- System validates that all required file upload fields have files before allowing form submission
- Client-side validation prevents submission with visual feedback
- Server-side validation ensures data integrity
- Clear error messages indicate which required fields are missing
- Form cannot be submitted until all required files are uploaded

**Test Scenario**: Given a form with required file upload fields, when a client attempts to submit the form without uploading files to required fields, then the form submission is blocked and error messages indicate which fields are missing files.

---

### 4. Corrupted or Invalid File Formats

**Edge Case**: How does the system handle corrupted or invalid file formats that pass extension validation?

**Handling Strategy**:
- Multi-layer validation: extension check → MIME type check → magic bytes validation
- Magic bytes validation reads file header to verify actual file type
- Files that fail any validation are rejected with clear error messages
- Invalid files are not stored in the system
- Implementation: Custom validation service that uses the `marcel` or `filemagic` gem for magic bytes detection

**Test Scenarios**:
- Given a client attempts to upload a file with a .pdf extension that is actually an executable, when the client selects the file, then the magic bytes validation detects the mismatch and rejects the file
- Given a client attempts to upload a corrupted image file, when the file is validated, then the system detects the corruption and rejects the file with an appropriate error message

---

### 5. Storage Limits Reached

**Edge Case**: What happens when storage limits are reached?

**Handling Strategy**:
- System monitors S3 bucket usage and storage quotas
- When storage limits are approached or reached, upload attempts return an error
- Clear error message indicates that file uploads are temporarily unavailable
- Error message does not expose internal system details
- System logs the event for monitoring and alerting
- Implementation: Rescue from `ActiveStorage::IntegrityError` and S3 quota errors

**Test Scenario**: Given storage limits have been reached, when a client attempts to upload a file, then the system displays an error message indicating that file uploads are temporarily unavailable due to storage constraints.

---

### 6. Concurrent Uploads from Multiple Clients

**Edge Case**: How does the system handle concurrent uploads from multiple clients?

**Handling Strategy**:
- System processes uploads independently with proper isolation
- Each client's uploads are associated with their specific form response and client ID
- Database transactions ensure data integrity
- Active Storage handles concurrent uploads to S3
- Rate limiting prevents abuse (10 uploads per client per minute)
- Performance target: support at least 50 concurrent clients with 5MB average file size

**Test Scenarios**:
- Given 50 clients are simultaneously uploading files, when all uploads complete, then all files are correctly associated with their respective clients and form responses
- Given multiple clients are uploading files, when one client's upload fails, then other clients' uploads are not affected

---

### 7. File Destruction After Download

**Edge Case**: What happens to files after a user downloads them?

**Handling Strategy**:
- Files are automatically destroyed from storage immediately after a successful download
- Download link becomes unavailable for subsequent access
- Implementation uses a two-step process:
  1. Generate short-lived signed URL (5-minute expiration)
  2. After successful download is confirmed, mark file as deleted and trigger async purge
- Background job handles actual blob deletion to avoid blocking the response
- File metadata is retained in database for audit purposes (90-day retention)

**Test Scenarios**:
- Given a user downloads a file from a client's show page, when the download completes, then the file is automatically destroyed from storage and the download link becomes unavailable
- Given a user attempts to download a file that was already downloaded, when the user clicks the download link, then an appropriate error message is displayed indicating the file is not available

---

### 8. Client Deletion

**Edge Case**: What happens to files when a client is deleted?

**Handling Strategy**:
- All files associated with the client are destroyed from storage when the client is deleted
- Database cascade deletion or explicit cleanup ensures all file references are removed
- Background jobs handle bulk deletion to avoid blocking the client deletion process
- Audit logs record the deletion activity for compliance

**Test Scenarios**:
- Given a client has uploaded multiple files, when the client is deleted, then all associated files are destroyed from storage
- Given a client is deleted, when the deletion process completes, then no file references remain in the database for that client

---

### 9. Abuse Prevention

**Edge Case**: How does the system prevent abuse of file upload endpoints?

**Handling Strategy**:
- Rate limiting enforced at 10 uploads per client per minute
- Implementation uses Rack::Attack or similar middleware
- Rate limit is per-client (authenticated), not per-IP
- Clear 429 (Too Many Requests) responses with Retry-After header
- Server-side validation ensures file size, type, and content constraints
- Authentication required for all upload operations
- Audit logging tracks all upload activities for 90 days

**Test Scenarios**:
- Given a client attempts to upload more than 10 files in one minute, when the 11th upload is attempted, then the system returns a 429 status code with a clear error message
- Given a client is rate-limited, when they wait for the rate limit window to expire, then they can resume uploading files

---

### 10. File Replacement

**Edge Case**: What happens when a client replaces a previously uploaded file with a new version?

**Handling Strategy**:
- New file completely replaces the old file in the same field
- Old file is marked as deleted and purged asynchronously
- Form response displays only the most recent file information
- File metadata (name, size, upload date) is updated to reflect the new file
- Download link points to the new file only

**Test Scenarios**:
- Given a client has uploaded a file to a form field, when the client uploads a new file to the same field, then the new file replaces the previous file and only the new file is available
- Given a client replaces a file, when a user views the client's show page, then only the most recent file is displayed and available for download

---

### 11. Expired Signed URLs

**Edge Case**: What happens when a user attempts to access a file with an expired signed URL?

**Handling Strategy**:
- Signed URLs expire after 5 minutes
- Attempted access with expired URL returns 403 Forbidden
- Clear error message indicates the link has expired
- User can request a new download link if the file still exists

**Test Scenario**: Given a user has a download link that has expired, when they attempt to access the file, then the system returns a 403 status with an appropriate error message.

---

### 12. File Deletion by User

**Edge Case**: What happens when a user manually deletes a file uploaded by a client?

**Handling Strategy**:
- User must confirm deletion before action proceeds
- File is removed from storage immediately after confirmation
- Download link becomes unavailable
- Form response shows that no file is currently uploaded for that field
- Audit log records the deletion activity

**Test Scenarios**:
- Given a user is viewing a client's show page with uploaded files, when the user initiates file deletion, then a confirmation dialog is displayed
- Given a user confirms file deletion, when the deletion completes, then the file is removed from storage and no longer appears on the client's show page

---

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

## Phase 0: Research & Technology Decisions

See [`research.md`](./research.md) for detailed research findings and technology decisions.

## Phase 1: Design Artifacts

### Data Model

See [`data-model.md`](./data-model.md) for the complete entity definitions, relationships, and state transitions.

### Controller Contracts

Upload and download endpoints follow standard Rails RESTful conventions within the existing Inertia architecture. No separate API contracts are needed -- controllers render Inertia responses or issue redirects (for downloads).

### Quickstart Guide

See [`quickstart.md`](./quickstart.md) for developer setup and initial implementation guidance.

## Phase 2: Implementation Tasks

See [`tasks.md`](./tasks.md) for the detailed task breakdown (created by `/speckit.tasks` command).
