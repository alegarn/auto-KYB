# Data Model: Client File Upload

Path: /home/a/Documents/Projets/quick-kyb/quick-kyb/specs/006-client-file-upload/data-model.md

Entities

1) UploadedFile
- Description: Represents a file uploaded by a client and associated to a form response.
- Persistence: ActiveRecord model backed by Active Storage (references ActiveStorage::Blob/Attachment)
- Fields:
  - id: UUID (primary key)
  - filename: string (original name)
  - content_type: string
  - byte_size: integer
  - checksum: string
  - service_name: string (e.g., s3)
  - storage_key: string (internal object key / active_storage.blob.key)
  - uploaded_at: datetime
  - downloaded_at: datetime (nullable)
  - deleted_at: datetime (nullable)
  - uploaded_by_client_id: UUID (FK)
  - downloaded_by_user_id: UUID (nullable)
  - form_response_id: UUID (FK)
  - client_id: UUID (FK)
  - metadata: jsonb (optional: image dimensions, extra metadata)
- Associations:
  - belongs_to :form_response
  - belongs_to :client
- Validations:
  - presence: filename, content_type, byte_size, storage_key
  - content_type inclusion: ['application/pdf','image/jpeg','image/png']
  - byte_size <= 10_485_760 (10MB)
  - magic-bytes validation performed on incoming uploads

2) FileUploadField
- Description: Form field configuration indicating allowed types and constraints
- Fields:
  - id: UUID
  - form_field_id: UUID (FK to the Form Builder's field)
  - allowed_types: array[string] default ['application/pdf','image/jpeg','image/png']
  - max_size_bytes: integer default 10_485_760
  - required: boolean
- Associations:
  - belongs_to :form_field (implementation-specific)

3) FormResponse (existing)
- Additions:
  - has_many :uploaded_files

Indexes
- uploaded_files: index on form_response_id, client_id, deleted_at
- uploaded_files: unique index on storage_key

State transitions
- uploaded -> available
- available -> downloaded (on successful download; sets deleted_at and downloaded_at; trigger async purge)
- available -> replaced (on replacement upload; old file marked deleted)
- deleted -> purged (after async background job removes active storage blob)

Notes
- Use Active Storage attachments to store binary data; maintain separate UploadedFile model to record metadata and business rules, making it easier to manage deletion-on-download semantics and associations.
- Background jobs (Active Job) will handle blob purging to avoid blocking web requests.
- Record downloaded_by_user_id and downloaded_at for audit logging and to support the deletion-after-download requirement.
