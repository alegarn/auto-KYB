import type { FormField, FormSettings } from '/components/customs/form-builder/types'

export type ModalState = 'idle' | 'uploading' | 'preview' | 'error'
export type ConfirmTarget = 'edit' | 'index'

export interface PreviewFormData {
  name: string
  structure: {
    description?: string
    settings?: FormSettings
    fields: FormField[]
  }
}

export interface PdfImportResult {
  form_data: PreviewFormData
  warnings: string[]
  field_count: number
}

export interface SummaryItem {
  key: string
  label: string
  count: number
}

export const MAX_FILE_SIZE_MB = 10
export const MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024
export const SLOW_UPLOAD_MESSAGE_DELAY_MS = 5000
export const SLOW_UPLOAD_MESSAGE_INTERVAL_MS = 5000
export const SLOW_UPLOAD_MESSAGES = [
  'Your pdf is still being processed',
  'Yes, still on process',
  'Not crashing yet...',
  'Hold on i heard something :o',
  "Oh no, i canno't hear i'm a web app...",
  'Wow, are you on 64kB connection?',
  'Did you gave a book to process?!',
  'Maybe there is a problem on the server side...',
  "At worse the biggest AI out there might process your pdf, cost a bunch, but when it's for you... $.$",
  "If you see that message, 55 seconds have passed at least... there might be problem somewhere. You can reload the page and retry.",
] as const

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

export function isPdfFile(selectedFile: File): boolean {
  const normalizedName = selectedFile.name.toLowerCase()
  return selectedFile.type === 'application/pdf' || normalizedName.endsWith('.pdf')
}

export function validateClientFile(selectedFile: File): string | null {
  if (!isPdfFile(selectedFile)) {
    return 'Only PDF files are accepted.'
  }

  if (selectedFile.size > MAX_FILE_SIZE_BYTES) {
    return `File too large (max ${MAX_FILE_SIZE_MB} MB).`
  }

  return null
}

export function buildErrorMessage(error?: string, details?: unknown, fallback = 'Import failed.'): string {
  if (!Array.isArray(details) || details.length === 0) {
    return error || fallback
  }

  return `${error || fallback} ${details.join(' ')}`.trim()
}

export function buildSummaryItems(fields: readonly FormField[]): SummaryItem[] {
  if (!fields.length) return []

  const counts = {
    inputs: 0,
    choices: 0,
    uploads: 0,
    tables: 0,
    layout: 0,
  }

  for (const field of fields) {
    switch (field.field_type) {
      case 'text':
      case 'number':
      case 'email':
      case 'date':
      case 'textarea':
        counts.inputs += 1
        break
      case 'checkbox':
      case 'buttons':
      case 'select':
      case 'radio':
        counts.choices += 1
        break
      case 'file':
        counts.uploads += 1
        break
      case 'table':
        counts.tables += 1
        break
      default:
        counts.layout += 1
    }
  }

  return [
    { key: 'inputs', label: 'Inputs', count: counts.inputs },
    { key: 'choices', label: 'Choices', count: counts.choices },
    { key: 'uploads', label: 'Uploads', count: counts.uploads },
    { key: 'tables', label: 'Tables', count: counts.tables },
    { key: 'layout', label: 'Layout', count: counts.layout },
  ].filter((item) => item.count > 0)
}

export function buildConfirmedFormData(formData: PreviewFormData, formName: string): PreviewFormData {
  return {
    ...formData,
    name: formName,
    structure: {
      ...formData.structure,
    },
  }
}

export function isPdfImportResult(payload: unknown): payload is PdfImportResult {
  if (!isRecord(payload) || payload.success !== true) return false

  const formData = payload.form_data
  if (!isRecord(formData)) return false
  if (typeof formData.name !== 'string') return false

  const structure = formData.structure
  if (!isRecord(structure)) return false
  if (!Array.isArray(structure.fields)) return false
  if (!Array.isArray(payload.warnings) || !payload.warnings.every((warning) => typeof warning === 'string')) return false

  return typeof payload.field_count === 'number'
}

export function isConfirmSuccessPayload(payload: unknown): payload is { success: true; form_id: string | number } {
  return isRecord(payload)
    && payload.success === true
    && (typeof payload.form_id === 'string' || typeof payload.form_id === 'number')
}
