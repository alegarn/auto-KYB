import { fireEvent, waitFor } from '@testing-library/svelte'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import FormResponse from '@/pages/ClientPortal/FormResponse.svelte'
import { renderPage } from '../helpers/renderPage'

const render = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  renderPage({ pageName: 'ClientPortal/FormResponse', component, props: options.props ?? {} })

const { autosaveState } = vi.hoisted(() => ({
  autosaveState: {
    partialSaves: [] as Record<string, any>[],
  },
}))

vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte')
  const { writable } = await import('svelte/store')
  return {
    ...(actual as any),
    useForm: (initial: Record<string, any> = {}) => {
      const store = writable<any>({})
      const form: any = {
        subscribe: store.subscribe,
        set: (value: Record<string, any>) => {
          Object.assign(form, value)
          store.set(form)
        },
        update: (updater: (current: Record<string, any>) => Record<string, any>) => {
          const next = updater(form) ?? form
          Object.assign(form, next)
          store.set(form)
        },
        defaults: (data: Record<string, any>) => {
          Object.assign(form, data)
          store.set(form)
        },
        transform: () => form,
        patch: (_url: string, options?: { onSuccess?: () => void }) => {
          options?.onSuccess?.()
        }
      }
      // initialize the store value to the form object so `$form` in components
      // refers to the object with methods (defaults/patch/transform)
      Object.assign(form, initial)
      store.set(form)
      return form
    }
  }
})

vi.mock('@/lib/form-response/autosave', async () => {
  const actual = await vi.importActual('@/lib/form-response/autosave')
  return {
    ...(actual as any),
    createAutosave: ({ onSave }: { onSave: () => Promise<void> }) => ({
      schedule: () => { void onSave() },
      cancel: () => {},
      flush: () => onSave(),
    }),
  }
})

vi.mock('@/lib/form-response/form-submit', () => ({
  createFormSubmitter: (deps: {
    getPartialData: () => Record<string, any>
    onAutosaveSuccess: (savedData: Record<string, any>) => void
  }) => ({
    submit: async () => {},
    savePartial: async () => {
      const savedData = deps.getPartialData()
      autosaveState.partialSaves.push(savedData)
      deps.onAutosaveSuccess(savedData)
    },
  })
}))

describe('ClientPortal FormResponse', () => {
  beforeEach(() => {
    autosaveState.partialSaves = []
  })

  it('only marks and saves the latest unsaved fields after consecutive autosaves', async () => {
    const portalForm = {
      name: 'Test Form',
      structure: { settings: {} },
      form_fields: [
        {
          id: 'field-1',
          label: 'First name',
          field_type: 'text',
          required: false,
          metadata: {},
        },
        {
          id: 'field-2',
          label: 'Last name',
          field_type: 'text',
          required: false,
          metadata: {},
        }
      ]
    }

    const { container, getAllByText, getByLabelText, rerender } = render(FormResponse, {
      props: {
        form: portalForm,
        last_response: null,
      }
    })

    const firstNameInput = getByLabelText('First name')
    await fireEvent.input(firstNameInput, { target: { value: 'Ada' } })

    await waitFor(() => {
      expect(autosaveState.partialSaves).toEqual([
        { 'field-1': 'Ada' },
      ])
    })

    await rerender({
      pageName: 'ClientPortal/FormResponse',
      component: FormResponse,
      componentProps: {
        form: portalForm,
        last_response: {
          data: { 'field-1': 'Ada' },
          version: 1,
        },
      },
    })

    const lastNameInput = getByLabelText('Last name')
    await fireEvent.input(lastNameInput, { target: { value: 'Lovelace' } })

    await waitFor(() => {
      expect(autosaveState.partialSaves).toEqual([
        { 'field-1': 'Ada' },
        { 'field-2': 'Lovelace' },
      ])
    })

    await waitFor(() => {
      expect(getAllByText('Saved')).toHaveLength(1)
    })

    const labels = Array.from(container.querySelectorAll('[data-slot="field-label"]'))
    expect(labels[0]?.textContent).not.toContain('Saved')
    expect(labels[1]?.textContent).toContain('Saved')
  })
})
