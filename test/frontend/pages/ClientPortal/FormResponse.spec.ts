import { render, fireEvent, waitFor } from '@testing-library/svelte'
import { describe, it, expect, vi } from 'vitest'
import FormResponse from '@/pages/ClientPortal/FormResponse.svelte'

vi.mock('@inertiajs/svelte', async () => {
  const { writable } = await import('svelte/store')
  return {
    useForm: (initial: Record<string, any> = {}) => {
      const store = writable<any>(null)
      const form: any = {
        subscribe: (run: any) => store.subscribe(run),
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

vi.mock('@/lib/form-response/autosave', () => ({
  createAutosave: ({ onSave }: { onSave: () => Promise<void> }) => ({
    schedule: () => { void onSave() },
    cancel: () => {},
    flush: () => onSave(),
  }),
  buildDelta: () => ({ 'field-1': 'value' }),
  mergeBase: (base: Record<string, any>, patch: Record<string, any>) => ({ ...base, ...patch }),
}))

vi.mock('@/lib/form-response/form-submit', () => ({
  createFormSubmitter: (deps: { onAutosaveSuccess: (fields: string[]) => void }) => ({
    submit: async () => {},
    savePartial: async () => { deps.onAutosaveSuccess(['field-1']) },
  })
}))

describe('ClientPortal FormResponse', () => {
  it('shows an autosave indicator after autosave', async () => {
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
        }
      ]
    }

    const { getByLabelText, getByText } = render(FormResponse, {
      props: {
        form: portalForm,
        last_response: null,
      }
    })

    const input = getByLabelText('First name')
    await fireEvent.input(input, { target: { value: 'Ada' } })

    await waitFor(() => {
      expect(getByText('Saved')).toBeInTheDocument()
    })
  })
})
