---

description: "Task list for Client File Upload System"
---

# Tasks: Client File Upload System

**Input**: Design documents from `/specs/006-client-file-upload/`

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 [P] Configure Active Storage for Amazon S3 in config/storage.yml
- [ ] T002 [P] Add AWS KMS and S3 credentials to config/credentials.yml.enc and document required env vars in .env.example
- [ ] T003 [P] Create initializer for Active Storage strict validations at config/initializers/active_storage.rb
- [ ] T004 [P] Add Rack::Attack rate limiting configuration at config/initializers/rack_attack.rb (10 uploads per client per minute)
- [ ] T005 [P] Add CI job step to run upload-related tests in .github/workflows/ci.yml

---

## Phase 2: Foundational (Blocking Prerequisites)

### Tests (write BEFORE implementation)

- [ ] T006a [P] [Foundation] Migration test for uploaded_files table in spec/migrations/20260213000000_create_uploaded_files_spec.rb
- [ ] T007a [P] [Foundation] Model test for UploadedFile in spec/models/uploaded_file_spec.rb
- [ ] T009a [P] [Foundation] Unit test for file validation service in spec/services/file_validation_service_spec.rb
- [ ] T010a [P] [Foundation] Unit test for file upload service in spec/services/file_upload_service_spec.rb
- [ ] T011a [P] [Foundation] Unit test for purge file job in spec/jobs/purge_file_job_spec.rb
- [ ] T012a [P] [Foundation] Unit test for file download service in spec/services/file_download_service_spec.rb

- [ ] T006 Implement DB migration for uploaded_files at db/migrate/20260213000000_create_uploaded_files.rb
- [ ] T007 Create model app/models/uploaded_file.rb with fields, associations, validations (UUID id, filename, content_type, byte_size, storage_key, uploaded_at, deleted_at, form_response_id, client_id)
- [ ] T008 Update app/models/form_response.rb to add has_many :uploaded_files
- [ ] T009 Implement file validation service with magic-bytes and MIME checks at app/services/file_validation_service.rb
- [ ] T010 Implement file upload service skeleton at app/services/file_upload_service.rb (validation, storage key generation, Active Storage attachment orchestration)
- [ ] T011 Implement background purge job at app/jobs/purge_file_job.rb to purge Active Storage blobs asynchronously
- [ ] T012 Configure ActiveJob adapter and queue settings for purge jobs in config/application.rb or config/environments/*.rb
- [ ] T013 Add indexes for uploaded_files on form_response_id, client_id, deleted_at and unique index on storage_key via migration
- [ ] T014 Add auditing/logging hook for uploaded file actions in app/models/uploaded_file.rb or app/services/audit_service.rb

---

## Phase 3: User Story 1 - Client File Upload (Priority: P1) 🎯 MVP

**Goal**: Allow clients to upload PDF/JPEG/PNG files to form response upload fields and associate files with the form response.

**Independent Test**: Client can open a form with an upload field, select a valid file, upload it, and see the uploaded file metadata associated with the form response.

### Tests (write BEFORE implementation)

- [ ] T015 [P] [US1] Contract test for POST /clients/{client_id}/form_responses/{form_response_id}/uploads in spec/contracts/upload_spec.rb
- [ ] T016 [P] [US1] System/integration test for client upload flow in spec/system/client_file_upload_system_spec.rb
- [ ] T016a [P] [US1] System test for Inertia upload progress + FormData submission in spec/system/client_file_upload_system_spec.rb

### Implementation

- [ ] T017 [P] [US1] Implement controller action for file upload at app/controllers/api/v1/uploaded_files_controller.rb (POST)
- [ ] T018 [P] [US1] Implement model attachment handling and metadata persistence in app/models/uploaded_file.rb (depends on T007)
- [ ] T019 [US1] Integrate file_validation_service into upload flow at app/services/file_upload_service.rb (depends on T009)
- [ ] T020 [US1] Add frontend upload component at app/frontend/components/file_upload/FileUploader.svelte and wire to POST endpoint
- [ ] T020a [US1] Implement upload submit via Inertia `useForm` in app/frontend/components/file_upload/FileUploader.svelte (bind file object and submit with `form.post`)
- [ ] T020b [US1] Enforce multipart handling using Inertia `forceFormData: true` for nested/conditional file payloads in app/frontend/components/file_upload/FileUploader.svelte
- [ ] T020c [US1] Ensure upload progress UI reads Inertia form progress (`form.progress.percentage`) in app/frontend/components/file_upload/UploadProgress.svelte
- [ ] T021 [US1] Add upload progress UI at app/frontend/components/file_upload/UploadProgress.svelte
- [ ] T022 [US1] Add server-side size/type checks and return 422 for invalid uploads in app/controllers/api/v1/uploaded_files_controller.rb

---

## Phase 4: User Story 2 - User File Download (Priority: P1)

**Goal**: Allow authenticated users to download client-uploaded files; downloads generate short-lived signed URLs and mark files as downloaded (then scheduled for purge).

**Independent Test**: User visits client show page, clicks download link, receives the original file, and the system marks the file as downloaded and schedules purge.

### Tests (write BEFORE implementation)

- [ ] T023 [P] [US2] Contract test for GET /uploads/{id}/download in spec/contracts/download_spec.rb
- [ ] T024 [P] [US2] System/integration test for download and post-download purge behavior in spec/system/file_download_system_spec.rb

### Implementation

- [ ] T025 [P] [US2] Implement download endpoint at app/controllers/uploads_controller.rb (GET /uploads/:id/download) to return 302 redirect to presigned S3 URL or JSON download_url
- [ ] T026 [US2] Implement file_download_service at app/services/file_download_service.rb to generate presigned URL, mark file as downloaded (set deleted_at) and enqueue purge job (depends on T011)
- [ ] T027 [US2] Wire download link to admin UI at app/frontend/pages/Admin/ClientShow.svelte
- [ ] T028 [US2] Add server-side handling for expired links and return 403/404 as appropriate in app/controllers/uploads_controller.rb

---

## Phase 5: User Story 3 - File Replacement (Priority: P2)

**Goal**: Allow a client to replace a previously uploaded file for the same field; old file is marked deleted and new file becomes the active one.

**Independent Test**: Client uploads a file, then uploads another to same field; verify the new file replaces the old and old file is marked deleted and scheduled for purge.

### Tests (write BEFORE implementation)

- [ ] T029 [P] [US3] Integration/system test for replacement flow in spec/system/file_replacement_system_spec.rb

### Implementation

- [ ] T030 [US3] Extend file_upload_service to support replacement semantics (mark previous uploaded_file.deleted_at, attach new blob) at app/services/file_upload_service.rb
- [ ] T031 [US3] Update app/models/uploaded_file.rb to support state transitions (available -> replaced -> purged)
- [ ] T032 [US3] Update FileUploader.svelte to support file replace UI and API call (app/frontend/components/file_upload/FileUploader.svelte)
- [ ] T032a [US3] Implement multipart-safe replacement via POST + method spoofing (`_method: 'put'` or `X-HTTP-METHOD-OVERRIDE`) in app/frontend/components/file_upload/FileUploader.svelte and matching Rails controller handling

---

## Phase 6: User Story 4 - File Deletion (Priority: P3)

**Goal**: Allow users to delete uploaded files from a client's show page with confirmation and immediate removal from availability.

**Independent Test**: User deletes a file from client show page, confirms action, and file is removed from storage and UI.

### Tests (write BEFORE implementation)

- [ ] T033 [P] [US4] Integration/system test for admin deletion with confirmation in spec/system/file_deletion_system_spec.rb

### Implementation

- [ ] T034 [US4] Implement DELETE /uploads/:id in app/controllers/uploads_controller.rb to mark deleted and enqueue purge job (app/controllers/uploads_controller.rb)
- [ ] T035 [US4] Add confirmation UI and wire delete action in app/frontend/pages/Admin/ClientShow.svelte
- [ ] T036 [US4] Ensure audit log entry created for deletion in app/services/audit_service.rb or app/models/uploaded_file.rb

---

## Final Phase: Polish & Cross-Cutting Concerns

- [ ] T037 [P] Update docs and quickstart at specs/006-client-file-upload/quickstart.md and docs/ to include developer setup and manual test steps
- [ ] T039 Run RuboCop and fix lint issues (project-wide)
- [ ] T040 Performance optimization: add N+1 guards and eager loading where appropriate (app/controllers and services)
- [ ] T041 [P] Add monitoring/metrics hooks for upload/download/purge events (logging/Prometheus metrics)
- [ ] T042 [P] [Performance] Concurrent upload load test in spec/performance/file_upload_concurrent_spec.rb to verify 50 clients can upload 5MB files simultaneously without performance degradation
- [ ] T043 [P] [Performance] Response time benchmark test in spec/performance/file_operations_benchmark_spec.rb to verify: upload progress < 1s, error display < 2s, 5MB upload < 30s, download < 5s

### Security Tests (write AFTER implementation)

- [ ] T044 [P] [Security] Encryption verification test in spec/security/file_encryption_spec.rb to verify uploaded files are encrypted at rest using AES-256
- [ ] T045 [P] [Security] Signed URL expiration test in spec/security/signed_url_expiration_spec.rb to verify download links expire after 5 minutes and return 403 Forbidden
---

## Dependencies & Execution Order

- Foundation (Phase 2) blocks all user stories and MUST complete before story implementation. All foundational test tasks (T006a, T007a, T009a, T010a, T011a, T012a) MUST be written and passing before their corresponding implementation tasks (T006, T007, T009, T010, T011, T026 where applicable). T012a (file_download_service unit test) must be completed and passing before T026 (file_download_service implementation).
- Performance tests T042 and T043 are POST-IMPLEMENTATION performance checks and MUST be written and executed after the corresponding implementation tasks (after T041 and after core upload/download flows are validated).
- Security tests T044 and T045 are POST-IMPLEMENTATION security checks and MUST be written and executed after the corresponding implementation tasks (after T026 for download-related checks and after core upload flows are validated). These tests verify NFR-001, NFR-002, NFR-003 and should be run in CI as part of release validation.
- User stories US1 and US2 are P1 and prioritized for MVP; US1 (upload) should be completed first to validate core flow; US2 (download) can proceed in parallel after Foundation
- US3 and US4 depend on US1/US2 primitives but are scoped later (P2, P3)
- Note: Inertia multipart uploads for non-POST requests must use method spoofing (`_method` param or `X-HTTP-METHOD-OVERRIDE`).

## Parallel Opportunities

- Setup tasks (T001-T005) can run in parallel
- Foundational tasks that touch different files can run in parallel (T007, T009, T011) but migrations (T006, T013) should be coordinated
- Within each user story, test tasks are parallelizable with model skeletons (marked [P])

## Implementation Strategy

- MVP: Complete Phase 1 + Phase 2, then implement Phase 3 (User Story 1) and validate independently
- Incremental: After US1 passes, implement US2, then US3, then US4

---

## File paths

Tasks reference these files (clickable in assistant responses):
- specs/006-client-file-upload/tasks.md
- specs/006-client-file-upload/plan.md
- specs/006-client-file-upload/spec.md
- db/migrate/20260213000000_create_uploaded_files.rb
- app/models/uploaded_file.rb
- app/services/file_upload_service.rb
- app/services/file_download_service.rb
- app/services/file_validation_service.rb
- app/controllers/api/v1/uploaded_files_controller.rb
- app/controllers/uploads_controller.rb
- app/jobs/purge_file_job.rb
- app/frontend/components/file_upload/FileUploader.svelte
- app/frontend/pages/Admin/ClientShow.svelte

---

Generated: 2026-02-13
