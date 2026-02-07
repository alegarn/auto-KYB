export type FieldType =
  | 'text'
  | 'number'
  | 'email'
  | 'date'
  | 'textarea'
  | 'checkbox'
  | 'select'
  | 'radio'
  | 'file'
  | 'table'
  | 'button';

export interface TableColumn {
  key: string;
  label: string;
  type: string;
}

export interface FieldValidation {
  min_length?: number;
  max_length?: number;
  pattern?: string;
  min?: number;
  max?: number;
}

export interface FileConfig {
  allowed_types?: string[];
  max_size_kb?: number;
}

export interface FieldMetadata {
  description?: string;
  placeholder?: string;
  options?: string[];
  allow_multiple?: boolean;
  validation?: FieldValidation;
  columns?: TableColumn[];
  file?: FileConfig;
}

export interface FormField {
  id?: string;
  label: string;
  field_type: FieldType;
  required: boolean;
  position: number;
  metadata: FieldMetadata;
}

export const FIELD_TYPE_LABELS: Record<FieldType, string> = {
  text: 'Text',
  number: 'Number',
  email: 'Email',
  date: 'Date',
  textarea: 'Text Area',
  checkbox: 'Checkbox',
  select: 'Dropdown',
  radio: 'Radio',
  file: 'File Upload',
  table: 'Table',
  button: 'Button',
};

export const FIELD_CATEGORIES: { name: string; types: FieldType[] }[] = [
  { name: 'Input', types: ['text', 'number', 'email', 'textarea'] },
  { name: 'Choice', types: ['select', 'radio', 'checkbox'] },
  { name: 'Other', types: ['date', 'file', 'table', 'button'] },
];

export function createField(fieldType: FieldType, position: number): FormField {
  const base: FormField = {
    label: FIELD_TYPE_LABELS[fieldType] + ' field',
    field_type: fieldType,
    required: false,
    position,
    metadata: {},
  };

  if (fieldType === 'select' || fieldType === 'radio') {
    base.metadata.options = ['Option 1', 'Option 2'];
  }
  if (fieldType === 'checkbox') {
    base.metadata.options = ['Option 1'];
    base.metadata.allow_multiple = false;
  }
  if (fieldType === 'table') {
    base.metadata.columns = [{ key: 'col_1', label: 'Column 1', type: 'text' }];
  }
  if (fieldType === 'file') {
    base.metadata.file = { max_size_kb: 5120 };
  }

  return base;
}
