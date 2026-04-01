import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, fireEvent, cleanup } from '@testing-library/svelte'
import FormBuilder from '@/components/customs/FormBuilder.svelte'
import type { FormField } from '@/components/customs/form-builder/types'

function buildField(overrides: Partial<FormField> = {}): FormField {
  const { metadata, ...rest } = overrides

  return {
    id: 'field-1',
    label: 'Test field',
    field_type: 'text',
    required: false,
    position: 1,
    ...rest,
    metadata: metadata ?? {},
  }
}

describe('FormBuilder', () => {
  afterEach(() => {
    cleanup()
    vi.clearAllMocks()
  })

  it('renders the right panel tabs', () => {
    const { getByText } = render(FormBuilder, { fields: [], settings: {} })

    expect(getByText('Field')).toBeInTheDocument()
    expect(getByText('Styling')).toBeInTheDocument()
    expect(getByText('Mapping')).toBeInTheDocument()
  })

  it('switches to Mapping panel when Mapping tab is clicked', async () => {
    const { getByText, queryByText } = render(FormBuilder, { fields: [], settings: {} })

    const mappingTab = getByText('Mapping')
    await fireEvent.click(mappingTab)

    expect(getByText('Data Export Mapping')).toBeInTheDocument()
    expect(queryByText('Form Styling')).not.toBeInTheDocument()
  })

  it('switches to Styling panel when Styling tab is clicked', async () => {
    const { getByText, queryByText } = render(FormBuilder, { fields: [], settings: {} })

    const stylingTab = getByText('Styling')
    await fireEvent.click(stylingTab)

    expect(getByText('Form Styling')).toBeInTheDocument()
    expect(queryByText('Data Export Mapping')).not.toBeInTheDocument()
  })

  it('switches to Field panel when Field tab is clicked', async () => {
    const { getByText, queryByText } = render(FormBuilder, { fields: [], settings: {} })

    // First switch to Mapping
    const mappingTab = getByText('Mapping')
    await fireEvent.click(mappingTab)
    expect(getByText('Data Export Mapping')).toBeInTheDocument()

    // Then switch back to Field
    const fieldTab = getByText('Field')
    await fireEvent.click(fieldTab)

    // Since no field is selected, it should show the "No field selected" message
    expect(getByText('No field selected')).toBeInTheDocument()
    expect(queryByText('Data Export Mapping')).not.toBeInTheDocument()
    expect(queryByText('Form Styling')).not.toBeInTheDocument()
  })

  it('shows mapping warning state and auto-opens Mapping tab when duplicates exist', () => {
    const fields: FormField[] = [
      buildField({ id: '1', label: 'Company Name', position: 1, metadata: { export_key: 'company_name' } }),
      buildField({ id: '2', label: 'Legal Name', position: 2, metadata: { export_key: 'company_name' } })
    ]

    const { getByText } = render(FormBuilder, {
      fields,
      settings: {},
      showMappingWarning: true,
    })

    const mappingTab = getByText('Mapping').closest('button')
    expect(mappingTab).toHaveClass('border-destructive')
    expect(getByText('Data Export Mapping')).toBeInTheDocument()
    expect(getByText('Not all fields are unique for export. Duplicate mapping keys found.')).toBeInTheDocument()
  })

  it('emits mapping validity callback with false when duplicates exist', () => {
    const fields: FormField[] = [
      buildField({ id: '1', label: 'Email', position: 1, metadata: { export_key: 'email' } }),
      buildField({ id: '2', label: 'Alt Email', position: 2, metadata: { export_key: 'email' } })
    ]
    const onmappingvaliditychange = vi.fn()

    render(FormBuilder, {
      fields,
      settings: {},
      onmappingvaliditychange,
    })

    expect(onmappingvaliditychange).toHaveBeenCalledWith(false)
  })

  it('shows CRM mapping warning with a CTA', async () => {
    const onopencrmmapping = vi.fn()

    const { getByText } = render(FormBuilder, {
      fields: [
        buildField({ id: '1', label: 'Company name', position: 1 })
      ],
      settings: {},
      showCrmMappingWarning: true,
      crmMappingWarningProviderName: 'HubSpot',
      unmappedCrmFieldLabels: ['Company name'],
      onopencrmmapping,
    })

    expect(getByText('Some fields will not export to HubSpot.')).toBeInTheDocument()

    await fireEvent.click(getByText('Open CRM field mapping'))
    expect(onopencrmmapping).toHaveBeenCalledTimes(1)
  })
})
