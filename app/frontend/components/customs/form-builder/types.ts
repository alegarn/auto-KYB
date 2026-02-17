export type FieldType =
  | 'text'
  | 'number'
  | 'email'
  | 'date'
  | 'textarea'
  | 'checkbox'
  | 'buttons'
  | 'select'
  | 'radio'
  | 'file'
  | 'table'
  /* | 'button' */
  | 'section'
  | 'subtitle'
  | 'static_text'
  | 'separator'
  | 'logo';

export interface TableColumn {
  key: string;
  label: string;
  type: string;
}

export interface TableConfig {
  columns: TableColumn[];
  min_rows?: number;
  max_rows?: number;
  default_row_count?: number;
  allow_add_rows?: boolean;
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

export interface SectionConfig {
  collapsible?: boolean;
  default_expanded?: boolean;
  border_style?: 'none' | 'subtle' | 'prominent';
}

export interface SeparatorConfig {
  thickness?: 'thin' | 'medium' | 'thick';
  color?: string;
  margin?: 'small' | 'medium' | 'large';
}

export interface LogoConfig {
  image_url?: string;
  width?: number;
  height?: number;
  alignment?: 'left' | 'center' | 'right';
}

export interface FieldMetadata {
  description?: string;
  placeholder?: string;
  instruction?: string;
  options?: string[];
  allow_multiple?: boolean;
  validation?: FieldValidation;
  columns?: TableColumn[];
  table?: TableConfig;
  file?: FileConfig;
  section?: SectionConfig;
  separator?: SeparatorConfig;
  logo?: LogoConfig;
  text_content?: string;
}

export interface FormField {
  id?: string;
  label: string;
  field_type: FieldType;
  required: boolean;
  position: number;
  metadata: FieldMetadata;
}

export interface FormSettings {
  primary_color?: string;
  logo_url?: string;
  header_background_color?: string;
  form_background_color?: string;
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
  /* button: 'Button', */
  buttons: 'Buttons',
  section: 'Section',
  subtitle: 'Subtitle',
  static_text: 'Text Block',
  separator: 'Separator',
  logo: 'Logo',
};

export const FIELD_CATEGORIES: { name: string; types: FieldType[] }[] = [
  { name: 'Input', types: ['text', 'number', 'email', 'textarea'] },
  { name: 'Choice', types: ['select', 'radio', 'checkbox'] },
  { name: 'Choice (UI)', types: ['buttons'] },
  { name: 'Data', types: ['date', 'file', 'table'] },
  { name: 'Layout', types: ['section', 'subtitle', 'static_text', 'separator', 'logo'] },
  /* { name: 'Action', types: ['button'] }, */
];

export function isLayoutField(fieldType: FieldType): boolean {
  return ['section', 'subtitle', 'static_text', 'separator', 'logo'].includes(fieldType);
}

/**
 * Allowed file extensions for file fields in the builder.
 * Stored canonical form includes the leading dot, e.g. ".pdf".
 */
export const ALLOWED_FILE_EXTENSIONS = ['.pdf', '.png', '.jpg', '.jpeg'] as const;

/**
 * Default allowed types used when creating a new file field.
 */
export const DEFAULT_ALLOWED_FILE_TYPES = [...ALLOWED_FILE_EXTENSIONS];

export function createField(fieldType: FieldType, position: number): FormField {
  const base: FormField = {
    label: FIELD_TYPE_LABELS[fieldType] + ' field',
    field_type: fieldType,
    required: false,
    position,
    metadata: {},
  };

  switch (fieldType) {
    case 'select':
    case 'radio':
      base.metadata.options = ['Option 1', 'Option 2'];
      break;
    case 'buttons':
      base.metadata.options = ['Option 1', 'Option 2'];
      base.metadata.allow_multiple = false;
      break;
    case 'checkbox':
      base.metadata.options = ['Option 1'];
      base.metadata.allow_multiple = false;
      break;
    case 'table':
      base.metadata.table = {
        columns: [{ key: 'col_1', label: 'Column 1', type: 'text' }],
        min_rows: 1,
        max_rows: 10,
        default_row_count: 1,
        allow_add_rows: true,
      };
      base.metadata.columns = base.metadata.table.columns;
      break;
    case 'file':
      base.metadata.file = { max_size_kb: 5120, allowed_types: DEFAULT_ALLOWED_FILE_TYPES };
      break;
    case 'section':
      base.label = 'Section Title';
      base.metadata.section = {
        collapsible: false,
        default_expanded: true,
        border_style: 'subtle',
      };
      break;
    case 'subtitle':
      base.label = 'Subtitle';
      break;
    case 'static_text':
      base.label = 'Information';
      base.metadata.text_content = 'Enter your text content here.';
      break;
    case 'separator':
      base.label = 'Separator';
      base.metadata.separator = {
        thickness: 'thin',
        margin: 'medium',
      };
      break;
    case 'logo':
      base.label = 'Logo';
      base.metadata.logo = {
        alignment: 'center',
        width: 200,
      };
      break;
  }

  return base;
}
