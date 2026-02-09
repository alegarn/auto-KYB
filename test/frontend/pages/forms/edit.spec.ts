import { render, fireEvent, waitFor } from '@testing-library/svelte'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import Edit from '@/pages/forms/edit.svelte'

vi.mock('@inertiajs/svelte', async () => {
  const { writable } = await import('svelte/store')
  return {
    page: writable({
      url: '/forms/1/edit',
      props: {
        user: { id: '1', email: 'test@example.com', name: 'Test User' },
        session_id: 'test-session-123'
      },
      component: 'Forms/Edit',
      version: '1.0'
    }),
    router: {
      patch: vi.fn(),
      visit: vi.fn(),
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
      reload: vi.fn()
    }
  }
})

// Keep a lightweight app sidebar mock to avoid rendering the full layout
vi.mock('@/components/customs/app-sidebar.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<div data-testid="app-sidebar">Sidebar</div>' }))
}))
vi.mock('/components/customs/app-sidebar.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<div data-testid="app-sidebar">Sidebar</div>' }))
}))

// Mock FormBuilder and FormFieldRenderer to avoid dynamic loader import issues
vi.mock('@/components/customs/FormBuilder.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<div data-testid="form-builder">Form Builder</div>' }))
}))
vi.mock('/components/customs/FormBuilder.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<div data-testid="form-builder">Form Builder</div>' }))
}))

vi.mock('@/components/customs/FormFieldRenderer.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<input id="field_field-1" name="field_field-1" aria-label="First Name" />' }))
}))
vi.mock('/components/customs/FormFieldRenderer.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<input id="field_field-1" name="field_field-1" aria-label="First Name" />' }))
}))
// Also mock the loader module used in the app to avoid runtime dynamic import issues
vi.mock('@/components/ui/loader/FormBuilderLoader.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<div data-testid="form-builder">Form Builder</div>' }))
}))
vi.mock('/components/ui/loader/FormBuilderLoader.svelte', () => ({
  default: vi.fn(() => ({ $$render: () => '<div data-testid="form-builder">Form Builder</div>' }))
}))

describe('Forms Edit Page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    document.body.innerHTML = ''
  })

  it('renders Edit Form heading', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    expect(getByText('Edit Form')).toBeInTheDocument()
  })

  it('displays form name input with initial value', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByLabelText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const nameInput = getByLabelText('Form Name')
    expect(nameInput).toBeInTheDocument()
    expect(nameInput).toHaveValue('Test Form')
  })

  it('shows Edit and Preview toggle buttons', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    expect(getByText('Edit')).toBeInTheDocument()
    expect(getByText('Preview')).toBeInTheDocument()
  })

  it('displays FormBuilder component in Edit mode by default', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { container } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    expect(container.querySelector('[data-testid="form-builder"]')).toBeTruthy()
  })

  it('switches to Preview mode when Preview button is clicked', async () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText, container } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(container.querySelector('[data-testid="form-builder"]')).toBeNull()
    })
  })

  it('displays preview form with form name in header when settings include header background color', async () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: {
        settings: {
          header_background_color: '#2563eb'
        }
      }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(getByText('Test Form')).toBeInTheDocument()
    })
  })

  it('shows Submit Preview button in Preview mode', async () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(getByText('Submit Preview')).toBeInTheDocument()
    })
  })

  it('displays preview results in JSON format after form submission', async () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [
        {
          id: 'field-1',
          label: 'First Name',
          field_type: 'text',
          required: false,
          position: 1,
          metadata: {}
        }
      ],
      structure: { settings: {} }
    }

    const { getByText, container } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(getByText('Submit Preview')).toBeInTheDocument()
    })

    const firstNameInput = container.querySelector('input[name="field_field-1"]')
    expect(firstNameInput).toBeTruthy()
    await fireEvent.input(firstNameInput as Element, { target: { value: 'John' } })

    const form = container.querySelector('form')
    if (form) {
      await fireEvent.submit(form)
    }

    await waitFor(() => {
      expect(getByText('Preview Results')).toBeInTheDocument()
      expect(getByText('JSON')).toBeInTheDocument()
      expect(getByText('CSV')).toBeInTheDocument()
    })
  })

  it('allows switching between JSON and CSV output formats', async () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [
        {
          id: 'field-1',
          label: 'First Name',
          field_type: 'text',
          required: false,
          position: 1,
          metadata: {}
        }
      ],
      structure: { settings: {} }
    }

    const { getByText, container } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(getByText('Submit Preview')).toBeInTheDocument()
    })

    const firstNameInput = container.querySelector('input[name="field_field-1"]')
    expect(firstNameInput).toBeTruthy()
    await fireEvent.input(firstNameInput as Element, { target: { value: 'John' } })

    const form = container.querySelector('form')
    if (form) {
      await fireEvent.submit(form)
    }

    await waitFor(() => {
      expect(getByText('Preview Results')).toBeInTheDocument()
    })

    const csvButton = getByText('CSV')
    await fireEvent.click(csvButton)

    await waitFor(() => {
      expect(getByText('Format: csv')).toBeInTheDocument()
    })
  })

  it('allows returning to Preview mode from results', async () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [
        {
          id: 'field-1',
          label: 'First Name',
          field_type: 'text',
          required: false,
          position: 1,
          metadata: {}
        }
      ],
      structure: { settings: {} }
    }

    const { getByText, container } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(getByText('Submit Preview')).toBeInTheDocument()
    })

    const firstNameInput = container.querySelector('input[name="field_field-1"]')
    expect(firstNameInput).toBeTruthy()
    await fireEvent.input(firstNameInput as Element, { target: { value: 'John' } })

    const form = container.querySelector('form')
    if (form) {
      await fireEvent.submit(form)
    }

    await waitFor(() => {
      expect(getByText('Preview Results')).toBeInTheDocument()
    })

    const backButton = getByText('Back to Preview')
    await fireEvent.click(backButton)

    await waitFor(() => {
      expect(getByText('Submit Preview')).toBeInTheDocument()
    })
  })

  it('displays client error when form name is empty on save', async () => {
    const fakeForm = {
      id: '1',
      name: '',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const saveButton = getByText('Save Changes and View')
    await fireEvent.click(saveButton)

    await waitFor(() => {
      expect(getByText('Name is required')).toBeInTheDocument()
    })
  })

  it('displays server error when provided', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: 'Server error occurred',
        session_id: 'test-session-123'
      }
    })

    expect(getByText('Server error occurred')).toBeInTheDocument()
  })

  it('displays server errors when provided as array', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: ['Error 1', 'Error 2'],
        error: null,
        session_id: 'test-session-123'
      }
    })

    expect(getByText('Error 1')).toBeInTheDocument()
    expect(getByText('Error 2')).toBeInTheDocument()
  })

  it('displays server errors when provided as object', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: { name: ['Name is invalid'] },
        error: null,
        session_id: 'test-session-123'
      }
    })

    expect(getByText('Name is invalid')).toBeInTheDocument()
  })

  it('calls router.patch with correct data when saving form', async () => {
    const { router } = await import('@inertiajs/svelte')

    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    const saveButton = getByText('Save Changes and View')
    await fireEvent.click(saveButton)

    await waitFor(() => {
      expect(router.patch).toHaveBeenCalledWith(
        '/forms/1',
        expect.objectContaining({
          form: expect.objectContaining({
            name: 'Test Form',
            structure: expect.objectContaining({
              settings: {},
              fields: []
            })
          })
        }),
        expect.any(Object)
      )
    })
  })

  it('displays Cancel button', () => {
    const fakeForm = {
      id: '1',
      name: 'Test Form',
      description: 'desc',
      form_fields: [],
      structure: { settings: {} }
    }

    const { getByText } = render(Edit, {
      props: {
        form: fakeForm,
        errors: null,
        error: null,
        session_id: 'test-session-123'
      }
    })

    expect(getByText('Cancel')).toBeInTheDocument()
  })
})
