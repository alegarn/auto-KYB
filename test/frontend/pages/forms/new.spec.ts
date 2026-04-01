import { fireEvent, waitFor } from '@testing-library/svelte'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import NewForm from '@/pages/forms/new.svelte'
import { renderPage } from '../helpers/renderPage'

const render = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  renderPage({ pageName: 'forms/new', component, props: options.props ?? {} })

vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte')
  const { writable } = await import('svelte/store')
  return {
    ...(actual as any),
    page: writable({
      url: '/forms/new',
      props: {
        user: { id: '1', email: 'test@example.com', name: 'Test User' },
        session_id: 'test-session-123'
      },
      component: 'Forms/New',
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

vi.mock('../../mocks/inertia', async () => {
  const actual = await vi.importActual('../../mocks/inertia')
  return actual
})


describe('Forms New Page', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    document.body.innerHTML = ''
  })

  it('renders Create Form heading', () => {
    const { getByRole } = render(NewForm, { props: { errors: null, session_id: 'test-session-123' } })
    expect(getByRole('heading', { name: 'Create Form' })).toBeInTheDocument()
  })

  it('displays form name input and Create Form button', () => {
    const { getByLabelText, getByRole } = render(NewForm, { props: { errors: null, session_id: 'test-session-123' } })
    expect(getByLabelText('Form Name')).toBeInTheDocument()
    expect(getByRole('button', { name: 'Create Form' })).toBeInTheDocument()
  })

  it('switches to Preview and back and shows results after submitting preview', async () => {
    const { getByText, getByRole, container } = render(NewForm, { props: { errors: null, session_id: 'test-session-123' } })

    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(getByText('Submit Preview')).toBeInTheDocument()
    })

    const form = container.querySelector('form')
    if (form) {
      await fireEvent.submit(form)
    }

    // After submitting preview with no fields we should still have the Create Form heading
    await waitFor(() => {
      expect(getByRole('heading', { name: 'Create Form' })).toBeInTheDocument()
    })
  })

  it('shows JSON and CSV results after submitting preview with fields', async () => {
    const { getByText, getByRole, container } = render(NewForm, { props: { errors: null, session_id: 'test-session-123' } })

    // Add a text field
    const textFieldBtn = getByText('Text')
    await fireEvent.click(textFieldBtn)

    // Switch to Preview
    const previewButton = getByText('Preview')
    await fireEvent.click(previewButton)

    await waitFor(() => {
      expect(getByText('Submit Preview')).toBeInTheDocument()
    })

    // Fill the field
    const input = container.querySelector('input[name="field_1"]') as HTMLInputElement
    if (input) {
      input.value = 'Test Value'
      input.setAttribute('value', 'Test Value')
      await fireEvent.input(input, { target: { value: 'Test Value' } })
      await fireEvent.change(input, { target: { value: 'Test Value' } })
    }

    // Submit preview
    const form = container.querySelector('form')
    if (form) {
      await fireEvent.submit(form)
    }

    // Check JSON results
    await waitFor(() => {
      expect(getByText('Preview Results')).toBeInTheDocument()
    })
    
    const pre = container.querySelector('pre')
    expect(pre?.textContent).toContain('"Text field": "Test Value"')

    // Switch to CSV
    const csvBtn = getByText('CSV')
    await fireEvent.click(csvBtn)

    expect(pre?.textContent).toContain('label,value')
    expect(pre?.textContent).toContain('Text field,Test Value')
  })

  it('calls router.post with correct data when creating form', async () => {
    const { router } = await import('@inertiajs/svelte')
    const { getByRole, getByLabelText } = render(NewForm, { props: { errors: null, session_id: 'test-session-123' } })

    const nameInput = getByLabelText('Form Name')
    await fireEvent.input(nameInput, { target: { value: 'New Test Form' } })

    const createButton = getByRole('button', { name: 'Create Form' })
    await fireEvent.click(createButton)

    await waitFor(() => {
      expect(router.post).toHaveBeenCalledWith(
        '/forms',
        expect.objectContaining({
          form: expect.objectContaining({
            name: 'New Test Form',
            structure: expect.objectContaining({ settings: expect.any(Object), fields: expect.any(Array) })
          })
        }),
        expect.any(Object)
      )
    })
  })

  it('warns before saving when a single active CRM has unmapped fields', async () => {
    const { router } = await import('@inertiajs/svelte')
    const { getByRole, getByLabelText, getByText, queryByText } = render(NewForm, {
      props: {
        errors: null,
        session_id: 'test-session-123',
        activeCrmProviders: ['hubspot'],
        crmProperties: {
          hubspot: {
            contact: [],
            company: [],
          },
        },
      }
    })

    await fireEvent.input(getByLabelText('Form Name'), { target: { value: 'CRM Form' } })
    await fireEvent.click(getByText('Text'))
    await fireEvent.click(getByRole('button', { name: 'Create Form' }))

    await waitFor(() => {
      expect(queryByText('Some fields will not export to your CRM')).toBeInTheDocument()
      expect(router.post).not.toHaveBeenCalled()
    })
  })
})
