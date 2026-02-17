# Data Model: Client File Upload

Path: specs/006-client-file-upload/data-model.md

Entities

1) UploadedFile
- Description: Business wrapper around an Active Storage attachment. Tracks lifecycle (download, deletion, replacement) and audit fields. Storage metadata (filename, content_type, byte_size, checksum) is read from the attached Active Storage blob -- not duplicated in this table.
- Persistence: ActiveRecord model with `has_one_attached :file`
- Fields:
  - id: UUID (primary key)
  - form_response_id: UUID (FK to form_responses)
  - client_id: UUID (FK to clients)
  - field_key: string (identifies which form field this upload belongs to)
  - status: string (enum: available, downloaded, replaced, purged) default 'available'
  - uploaded_at: datetime default now()
  - downloaded_at: datetime (nullable)
  - deleted_at: datetime (nullable)
  - downloaded_by_user_id: UUID (nullable, FK to users)
  - metadata: jsonb (optional: image dimensions, extra metadata)
- Associations:
  - belongs_to :form_response
  - belongs_to :client
  - belongs_to :downloaded_by_user, class_name: 'User', optional: true
  - has_one_attached :file
- Validations:
  - presence: field_key
  - file content_type inclusion: ['application/pdf', 'image/jpeg', 'image/png'] (via Active Storage validations)
  - file byte_size <= 10_485_760 (10MB) (via Active Storage validations)
  - magic-bytes validation performed by FileValidationService before attachment
- Delegated from blob (read-only, not stored in uploaded_files table):
  - filename: via file.filename
  - content_type: via file.content_type
  - byte_size: via file.byte_size
  - checksum: via file.checksum

2) FormField (existing -- no new table needed)
- File upload field configuration is stored in the existing form_fields.metadata JSONB column.
- When field_type is 'file_upload', metadata contains:
  - allowed_types: array[string] default ['application/pdf', 'image/jpeg', 'image/png']
  - max_size_bytes: integer default 10_485_760
  - required: boolean
- No separate FileUploadField model or table is created. This keeps file upload fields consistent with how all other field types store their configuration.

3) FormResponse (existing)
- Additions:
  - has_many :uploaded_files, dependent: :destroy

4) Client (existing)
- Additions:
  - has_many :uploaded_files, dependent: :destroy (for cascade cleanup when a client is deleted)

Indexes
- uploaded_files: index on form_response_id
- uploaded_files: index on client_id
- uploaded_files: index on [form_response_id, field_key] (for lookups by field within a response)
- uploaded_files: index on deleted_at (for purge job queries)

State transitions
- available: file is attached and accessible
- available -> downloaded: on successful user download (sets downloaded_at, downloaded_by_user_id, deleted_at; triggers async purge)
- available -> replaced: on replacement upload by client (old file marked deleted_at; triggers async purge)
- downloaded/replaced -> purged: after async background job removes Active Storage blob

Notes
- Use `has_one_attached :file` on UploadedFile to delegate binary storage to Active Storage. This avoids duplicating blob metadata (filename, content_type, byte_size, checksum) in the uploaded_files table.
- Background jobs (Active Job) handle blob purging to avoid blocking web requests.
- The field_key column links an uploaded file to a specific form field within the response, enabling replacement semantics (find existing upload for the same field_key, mark as replaced).
- Record downloaded_by_user_id and downloaded_at for audit logging and to support the deletion-after-download requirement.
