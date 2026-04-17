export type CrmMappingValue = {
  type: 'custom' | 'existing';
  object_type: string;
  property_name: string;
  read_only?: boolean;
};

export type CrmMappings = Record<string, Record<string, CrmMappingValue>>;
export type CrmExportKeyOverrides = Record<string, string>;
export type CrmOptionsOverrides = Record<string, string[]>;

export interface CrmMappingField {
  id?: string | number | null;
  label?: string | null;
  field_type: string;
  required?: boolean;
  position?: number;
  metadata?: Record<string, any>;
}

export interface CrmMappingIndexedField {
  field: CrmMappingField;
  index: number;
}

export interface CrmInventoryProperty {
  name?: string | null;
  label?: string | null;
  type?: string | null;
  field_type?: string | null;
  read_only?: boolean;
  options?: Array<{ label?: string | null; value?: string | null }>;
}

export type CrmProviderProperties = Record<string, CrmInventoryProperty[]>;

export interface CrmAiAutoMapField {
  id: string;
  label: string;
  field_type: string;
  required?: boolean;
  position?: number;
  metadata?: {
    export_key?: string;
    allow_multiple?: boolean;
    options?: string[];
  };
}

export interface CrmAiAutoMapRequest {
  unmappedFields: CrmAiAutoMapField[];
  alreadyMapped: string[];
  pendingFieldKeys: string[];
  draftFields: CrmAiAutoMapField[];
  totalUnmappedCount: number;
  allUnmappedFieldIds: string[];
}

export interface CrmAiAutoMapRequestOptions {
  batchSize?: number;
  fieldIds?: string[];
}

export interface CrmMappingDraftState {
  mappings: CrmMappings;
  exportKeyOverrides: CrmExportKeyOverrides;
  optionsOverrides: CrmOptionsOverrides;
}

export interface CrmMappingValidationIssue {
  provider: string;
  field_key: string;
  field_id?: string | null;
  index: number;
  field_label: string;
  object_type: string;
  property_name: string;
  code: string;
  message: string;
  invalid_options?: string[];
  allowed_options?: string[];
}

export type CrmMappingValidationIssueGroups = Record<string, Record<string, CrmMappingValidationIssue[]>>;
