# Feature Specification: Client File Upload System

**Feature Branch**: `006-client-file-upload`
**Created**: 2026-02-13
**Status**: Updated (post-merge reviews)
**Merged PRs**:

- **#70 — 006-client-file-upload-destroy-action (2026-02-17):** Adds destroy action and server-side deletion logic for uploaded files; review retention and dependent destroy behavior.
- **#62 — 006-client-file-upload-fix-routes (2026-02-16):** Routing fixes for upload/download endpoints; confirm request/feature specs use updated routes.
- **#61 — 006-client-file-upload-csrf-fix (2026-02-14):** CSRF handling for upload endpoints; ensure request specs exercise CSRF tokens where required.
**Input**: User description: "Let's have a file upload system for the client's form. The user create forms in a form builder with the file upload field (done), link them to clients (done), and on the client's portal form (done) a client should be able to upload files like pdf/jpeg/png to a remote location, and the user to download the files from the client's show page (to do)."

## Clarifications

### Session 2026-02-13

- Q: What security level is required for file storage and access? → A: Private storage with expiring signed URLs (files not publicly accessible)
- Q: What file retention and archival policy should be implemented? → A: Destruction on user download or client deletion
- Q: How should the system handle file upload failures and retries? → A: Auto-retry once, then require manual intervention
- Q: What storage service should be used for remote file storage? → A: Active Storage (Rails built-in, supports multiple providers)
- Q: What is the maximum file size limit per upload? → A: 10MB (standard for document uploads)
- Q: What accessibility standard should the file upload and download UI comply with? → A: WCAG 2.1 Level AA
- Q: Which cloud storage provider should Active Storage be configured to use for file storage? → A: Amazon S3
- Q: How deep should the file validation be for detecting corrupted or invalid files? → A: MIME type + magic bytes validation
- Q: Should rate limiting be applied to file upload endpoints to prevent abuse? → A: Yes, 10 uploads per client per minute
- Q: What file naming convention should be used for uploaded files in storage? → A: UUID-based with original filename preserved
- Q: What encryption key management approach should be used for file encryption at rest? → A: AWS KMS for automatic key rotation and centralized management
- Q: What should be the expiration time for signed URLs used for file downloads? → A: 5 minutes
- Q: What should be the exponential backoff parameters for auto-retrying failed file uploads? → A: 2 seconds initial delay, doubling to 4 seconds
- Q: What should be the retention period for audit logs of file upload, download, and deletion activities? → A: 90 days
- Q: What should be the expected file size for the concurrent upload performance target of 50 clients? → A: 5MB average file size

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Client File Upload (Priority: P1)

As a client, I want to upload files (PDF, JPEG, PNG) to form fields designated for file uploads, so that I can provide required documents and complete the form submission.

**Why this priority**: This is the core functionality of the feature. Without client file upload, the feature provides no value. This must work first to enable all other user journeys.

**Independent Test**: Can be fully tested by a client accessing their form, selecting a file upload field, uploading a valid file, and verifying the file is successfully stored and associated with their form response.

**Acceptance Scenarios**:

1. **Given** a client is viewing a form that contains at least one file upload field, **When** the client selects a valid PDF, JPEG, or PNG file and submits the upload, **Then** the file is successfully uploaded and stored
2. **Given** a client has uploaded a file to a file upload field, **When** the client views the form response, **Then** the uploaded file name and size are displayed
3. **Given** a client is uploading a file, **When** the file upload is in progress, **Then** a progress indicator is displayed showing the upload status
4. **Given** a client attempts to upload an invalid file type (e.g., .exe, .doc), **When** the client selects the file, **Then** an error message is displayed indicating the file type is not supported
5. **Given** a client attempts to upload a file exceeding the maximum allowed size, **When** the client selects the file, **Then** an error message is displayed indicating the file is too large

---

### User Story 2 - User File Download (Priority: P1)

As a user, I want to download files that clients have uploaded to their form responses, so that I can review and process the documents submitted by clients.

**Why this priority**: This is the primary value proposition for users. Without the ability to download and review client-uploaded files, the file upload feature provides no business value to users.

**Independent Test**: Can be fully tested by a user accessing a client's show page, locating a file uploaded by the client, and clicking the download link to verify the file downloads correctly.

**Acceptance Scenarios**:

1. **Given** a user is viewing a client's show page, **When** the client has uploaded files to their form responses, **Then** each uploaded file is displayed with a download link
2. **Given** a user clicks a download link for a client-uploaded file, **When** the download completes, **Then** the downloaded file matches the original file uploaded by the client and the file is destroyed from storage
3. **Given** a user is viewing a client's show page, **When** a file was uploaded by the client, **Then** the file display includes the file name, file type, and upload date
4. **Given** a user attempts to download a file that has been deleted or is no longer available, **When** the user clicks the download link, **Then** an appropriate error message is displayed indicating the file is not available
5. **Given** a user downloads a file, **When** the download completes, **Then** the file is automatically destroyed from storage and is no longer available for subsequent downloads

---

### User Story 3 - File Replacement (Priority: P2)

As a client, I want to replace a previously uploaded file with a new version, so that I can correct mistakes or update documents without needing to contact support.

**Why this priority**: File replacement is important for user autonomy and reducing support burden, but it's secondary to the core upload and download functionality. Users can initially work with a "no replacement" constraint if needed.

**Independent Test**: Can be fully tested by a client uploading a file, then uploading a new file to the same field, and verifying the new file replaces the old one.

**Acceptance Scenarios**:

1. **Given** a client has already uploaded a file to a form field, **When** the client uploads a new file to the same field, **Then** the new file replaces the previous file
2. **Given** a client replaces a file, **When** the replacement is complete, **Then** the form response displays the new file information (name, size, upload date)
3. **Given** a client replaces a file, **When** a user views the client's show page, **Then** only the most recent file is available for download

---

### User Story 4 - File Deletion (Priority: P3)

As a user, I want to delete files uploaded by clients, so that I can manage storage and remove inappropriate or unnecessary documents.

**Why this priority**: File deletion is an administrative function that provides control over data retention. It's valuable but not critical for initial feature delivery.

**Independent Test**: Can be fully tested by a user accessing a client's show page, selecting a file for deletion, confirming the action, and verifying the file is removed and no longer downloadable.

**Acceptance Scenarios**:

1. **Given** a user is viewing a client's show page with uploaded files, **When** the user initiates file deletion, **Then** a confirmation dialog is displayed
2. **Given** a user confirms file deletion, **When** the deletion completes, **Then** the file is removed from storage and no longer appears on the client's show page
3. **Given** a client attempts to access a form response with a deleted file, **When** the form response loads, **Then** the file upload field shows that no file is currently uploaded
4. **Given** a user downloads a file from a client's show page, **When** the download completes, **Then** the file is automatically destroyed from storage and the download link becomes unavailable for subsequent access

---

### Edge Cases

- What happens when a client tries to upload a file with the same name as an existing file? System handles this by generating a unique identifier for each uploaded file, preventing naming conflicts.
- How does the system handle network interruptions during file upload? System auto-retries once with exponential backoff, then displays an error message and requires manual retry by the client.
- What happens when a client submits a form without uploading required files? System validates that all required file upload fields have files before allowing form submission.
- How does the system handle corrupted or invalid file formats that pass extension validation? System performs basic file validation and rejects files that cannot be properly read or processed.
- What happens when storage limits are reached? System displays an error message indicating that file uploads are temporarily unavailable due to storage constraints.
- How does the system handle concurrent uploads from multiple clients? System processes uploads independently and ensures file isolation between different client responses.
- What happens to files after a user downloads them? Files are automatically destroyed from storage immediately after a successful download, making them unavailable for subsequent downloads.
- What happens to files when a client is deleted? All files associated with the client are destroyed from storage when the client is deleted.
- How does the system prevent abuse of file upload endpoints? Rate limiting is enforced at 10 uploads per client per minute.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow clients to upload files to form fields designated as file upload type
- **FR-002**: System MUST accept files in PDF, JPEG, and PNG formats
- **FR-003**: System MUST reject files in unsupported formats with clear error messages
- **FR-004**: System MUST enforce maximum file size limit of 10MB per upload
- **FR-005**: System MUST display upload progress indicators during file upload
- **FR-006**: System MUST store uploaded files using Active Storage (Rails built-in, supports multiple providers)
- **FR-007**: System MUST encrypt all files at rest with key management
- **FR-008**: System MUST associate uploaded files with the specific form response and client
- **FR-009**: System MUST display file information (name, type, size, upload date) after successful upload
- **FR-010**: System MUST allow users to download files uploaded by clients from the client's show page
- **FR-011**: System MUST ensure downloaded files match the original uploaded files
- **FR-012**: System MUST allow clients to replace previously uploaded files with new versions
- **FR-013**: System MUST replace the old file completely when a new file is uploaded to the same field
- **FR-014**: System MUST allow users to delete files uploaded by clients
- **FR-015**: System MUST require confirmation before deleting files
- **FR-016**: System MUST remove deleted files from storage and make them unavailable for download
- **FR-017**: System MUST validate that all required file upload fields have files before allowing form submission
- **FR-018**: System MUST auto-retry failed uploads once with exponential backoff (2 seconds initial delay, doubling to 4 seconds) before requiring manual intervention
- **FR-019**: System MUST generate unique identifiers for each uploaded file to prevent naming conflicts
- **FR-020**: System MUST perform MIME type and magic bytes validation to detect corrupted or invalid files
- **FR-021**: System MUST display appropriate error messages when storage limits prevent file uploads
- **FR-022**: System MUST destroy files from storage immediately after a user downloads them
- **FR-023**: System MUST destroy all files associated with a client when the client is deleted
- **FR-024**: System MUST enforce rate limiting of 10 file uploads per client per minute

### Key Entities

- **Uploaded File**: Represents a file uploaded by a client to a form field. Key attributes include file name, file type, file size, upload date, storage location, unique identifier (UUID), and encryption status. Associated with a specific form response and client. Maximum size: 10MB. Stored using UUID-based naming with original filename preserved for display.
- **File Upload Field**: Represents a form field designated for file uploads. Key attributes include allowed file types (PDF, JPEG, PNG), maximum file size (10MB), and whether the field is required.
- **Form Response**: Represents a client's submission of a form. Contains all field values including references to uploaded files.

### Non-Functional Requirements

#### Security & Privacy
- **NFR-001**: System MUST encrypt all uploaded files at rest using industry-standard encryption (AES-256)
- **NFR-002**: System MUST implement secure key management for file encryption keys using AWS KMS for automatic key rotation and centralized management
- **NFR-003**: System MUST use expiring signed URLs for file downloads to prevent unauthorized access, with a 5-minute expiration time
- **NFR-004**: System MUST log all file upload, download, and deletion activities for audit purposes with a 90-day retention period
- **NFR-005**: System MUST validate file content (not just extension) to prevent malicious file uploads

#### Performance & Scalability
- **NFR-006**: System MUST support concurrent uploads from at least 50 clients with 5MB average file size without performance degradation
- **NFR-007**: File upload progress updates MUST be displayed within 1 second of upload initiation
- **NFR-008**: Invalid file type errors MUST be displayed within 2 seconds of file selection
- **NFR-009**: System MUST complete file uploads for 5MB files within 30 seconds on standard broadband connection
- **NFR-010**: System MUST complete file downloads within 5 seconds on standard broadband connection

#### Accessibility
- **NFR-014**: System MUST comply with WCAG 2.1 Level AA accessibility standards for file upload and download interfaces
- **NFR-015**: File upload components MUST support keyboard navigation and screen reader announcements
- **NFR-016**: Progress indicators and error messages MUST be accessible to assistive technologies

#### Reliability & Availability
- **NFR-011**: System MUST achieve 99% successful file upload rate
- **NFR-012**: System MUST provide clear error messages for all failure scenarios
- **NFR-013**: System MUST auto-retry failed uploads once with exponential backoff (2 seconds initial delay, doubling to 4 seconds) before requiring manual intervention

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Clients can successfully upload a 10MB PDF file in under 30 seconds on standard broadband connection
- **SC-002**: Users can download client-uploaded files within 5 seconds on standard broadband connection
- **SC-003**: 99% of file uploads complete successfully without errors
- **SC-004**: 95% of clients successfully complete file uploads on their first attempt
- **SC-005**: File upload progress updates are displayed within 1 second of upload initiation
- **SC-006**: Invalid file type errors are displayed within 2 seconds of file selection
- **SC-007**: System supports concurrent uploads from at least 50 clients with 5MB average file size without performance degradation
- **SC-008**: File replacement completes within 30 seconds for files up to 10MB
- **SC-009**: File deletion completes within 5 seconds and the file is immediately unavailable for download

## Assumptions

- File upload fields have already been implemented in the form builder (as stated by user)
- Forms can be linked to clients (as stated by user)
- Client portal form access is already implemented (as stated by user)
- Maximum file size limit is 10MB per file (standard for document uploads)
- Remote storage is implemented using Active Storage with Amazon S3 as the storage provider
- All files are encrypted at rest with key management using AWS KMS for automatic key rotation and centralized management
- Files are destroyed when downloaded by a user or when the client is deleted
- File type validation is performed by checking file extensions, MIME types, and magic bytes for enhanced security
