import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, fireEvent, cleanup } from '@testing-library/svelte'
import FormBuilder from '@/components/customs/FormBuilder.svelte'

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
    const fields = [
      { id: '1', label: 'Company Name', field_type: 'text', required: false, position: 1, metadata: { export_key: 'company_name' } },
      { id: '2', label: 'Legal Name', field_type: 'text', required: false, position: 2, metadata: { export_key: 'company_name' } }
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
    const fields = [
      { id: '1', label: 'Email', field_type: 'text', required: false, position: 1, metadata: { export_key: 'email' } },
      { id: '2', label: 'Alt Email', field_type: 'text', required: false, position: 2, metadata: { export_key: 'email' } }
    ]
    const onmappingvaliditychange = vi.fn()

    render(FormBuilder, {
      fields,
      settings: {},
      onmappingvaliditychange,
    })

    expect(onmappingvaliditychange).toHaveBeenCalledWith(false)
  })
})
