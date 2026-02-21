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
})
