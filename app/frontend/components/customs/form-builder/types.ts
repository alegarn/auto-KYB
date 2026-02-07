// types.ts
// Shared types for the FormBuilder components. Keep these synchronized with the server-side shape.

export type FieldType = 'text'|'number'|'email'|'date'|'textarea'|'checkbox'|'select'|'radio'|'file'|'table'|'submit'|'reset';

export interface TableColumn {
  name: string;
  type: string;
  validation?: Record<string, any>;
}

export interface FieldMetadata {
  options?: string[]; // for select/radio
  validation?: Record<string, any>; // e.g. { pattern: "^\\d+$", min: 1 }
  columns?: TableColumn[]; // for table fields
  file?: { allowedTypes?: string[]; maxSizeKb?: number };
}

export interface FormField {
  id?: number | string; // optional (server-created id)
  label: string;
  field_type: FieldType;
  required?: boolean;
  position?: number;
  metadata?: FieldMetadata;
}

// NOTE: The server expects `form[structure][fields]` as an ordered array of field objects.
// Keep the JSON shape compatible with `FormService.create_form` and `update_form`.
