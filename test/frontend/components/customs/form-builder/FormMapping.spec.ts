import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, fireEvent, cleanup } from '@testing-library/svelte'
import FormMapping from '@/components/customs/form-builder/FormMapping.svelte'

describe('FormMapping', () => {
  afterEach(() => {
    cleanup()
  })

  it('renders the mapping panel with fields', () => {
    const fields = [
      { id: '1', label: 'First Name', field_type: 'text', position: 1 },
      { id: '2', label: 'Last Name', field_type: 'text', position: 2 }
    ]
    const onupdate = vi.fn()

    const { getByText, getByLabelText } = render(FormMapping, { fields, onupdate })

    expect(getByText('Data Export Mapping')).toBeInTheDocument()
    expect(getByLabelText('First Name')).toBeInTheDocument()
    expect(getByLabelText('Last Name')).toBeInTheDocument()
  })

  it('filters out layout fields', () => {
    const fields = [
      { id: '1', label: 'First Name', field_type: 'text', position: 1 },
      { id: '2', label: 'Section', field_type: 'section', position: 2 }
    ]
    const onupdate = vi.fn()

    const { getByLabelText, queryByLabelText } = render(FormMapping, { fields, onupdate })

    expect(getByLabelText('First Name')).toBeInTheDocument()
    expect(queryByLabelText('Section')).not.toBeInTheDocument()
  })

  it('filters out all layout field types (section, subtitle, static_text, separator, logo)', () => {
    const fields = [
      { id: '1', label: 'Text', field_type: 'text', position: 1 },
      { id: '2', label: 'My Section', field_type: 'section', position: 2 },
      { id: '3', label: 'My Subtitle', field_type: 'subtitle', position: 3 },
      { id: '4', label: 'My Info', field_type: 'static_text', position: 4 },
      { id: '5', label: 'My Separator', field_type: 'separator', position: 5 },
      { id: '6', label: 'My Logo', field_type: 'logo', position: 6 }
    ]
    const onupdate = vi.fn()

    const { queryByLabelText, getByLabelText } = render(FormMapping, { fields, onupdate })

    expect(getByLabelText('Text')).toBeInTheDocument()
    expect(queryByLabelText('My Section')).not.toBeInTheDocument()
    expect(queryByLabelText('My Subtitle')).not.toBeInTheDocument()
    expect(queryByLabelText('My Info')).not.toBeInTheDocument()
    expect(queryByLabelText('My Separator')).not.toBeInTheDocument()
    expect(queryByLabelText('My Logo')).not.toBeInTheDocument()
  })

  it('updates export_key when input changes', async () => {
    const fields = [
      { id: '1', label: 'First Name', field_type: 'text', position: 1 }
    ]
    const onupdate = vi.fn()

    const { getByLabelText } = render(FormMapping, { fields, onupdate })

    const input = getByLabelText('First Name')
    await fireEvent.input(input, { target: { value: 'first_name_custom' } })

    expect(onupdate).toHaveBeenCalledWith(0, {
      metadata: { export_key: 'first_name_custom' }
    })
  })

  it('applies snake_case transformation to all fields', async () => {
    const fields = [
      { id: '1', label: 'First Name', field_type: 'text', position: 1 },
      { id: '2', label: 'Last Name', field_type: 'text', position: 2 }
    ]
    const onupdate = vi.fn()

    const { getByText } = render(FormMapping, { fields, onupdate })

    const snakeCaseBtn = getByText('snake_case')
    await fireEvent.click(snakeCaseBtn)

    expect(onupdate).toHaveBeenCalledWith(0, { metadata: { export_key: 'first_name' } })
    expect(onupdate).toHaveBeenCalledWith(1, { metadata: { export_key: 'last_name' } })
  })

  it('applies kebab-case transformation to all fields', async () => {
    const fields = [
      { id: '1', label: 'First Name', field_type: 'text', position: 1 }
    ]
    const onupdate = vi.fn()

    const { getByText } = render(FormMapping, { fields, onupdate })

    const kebabCaseBtn = getByText('kebab-case')
    await fireEvent.click(kebabCaseBtn)

    expect(onupdate).toHaveBeenCalledWith(0, { metadata: { export_key: 'first-name' } })
  })

  it('applies camelCase transformation to all fields', async () => {
    const fields = [
      { id: '1', label: 'First Name', field_type: 'text', position: 1 }
    ]
    const onupdate = vi.fn()

    const { getByText } = render(FormMapping, { fields, onupdate })

    const camelCaseBtn = getByText('camelCase')
    await fireEvent.click(camelCaseBtn)

    expect(onupdate).toHaveBeenCalledWith(0, { metadata: { export_key: 'firstName' } })
  })

  it('resets to default (removes export_key)', async () => {
    const fields = [
      { id: '1', label: 'First Name', field_type: 'text', position: 1, metadata: { export_key: 'custom_key' } }
    ]
    const onupdate = vi.fn()

    const { getByText } = render(FormMapping, { fields, onupdate })

    const defaultBtn = getByText('default')
    await fireEvent.click(defaultBtn)

    expect(onupdate).toHaveBeenCalledWith(0, { metadata: {} })
  })
})
