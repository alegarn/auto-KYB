import { screen } from '@testing-library/svelte'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, beforeEach, vi } from 'vitest'

import Login from '../../../../app/frontend/pages/ClientPortal/Login.svelte'
import { renderPage } from '../helpers/renderPage'

const render = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  renderPage({ pageName: 'ClientPortal/Login', component, props: options.props ?? {} })

vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte')
  const { writable } = await import('svelte/store')

  return {
    ...(actual as any),
    useForm: (initial: Record<string, any> = {}) => {
      const store = writable<any>(null)
      const form: any = {
        subscribe: (run: any) => store.subscribe(run),
        transform: () => form,
        post: (_url: string, options?: { onSuccess?: () => void }) => {
          options?.onSuccess?.()
        },
      }
      Object.assign(form, initial)
      store.set(form)
      return form
    },
  }
})

describe('ClientPortal/Login', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders password input and submit button and emits login event', async () => {
    const user = userEvent.setup()
    const onLogin = vi.fn()
    render(Login, { props: { access_token: 'tok-123', onLogin } })

    const password = screen.getByLabelText(/password/i)
    expect(password).toBeInTheDocument()

    const submit = screen.getByRole('button', { name: /login/i })
    expect(submit).toBeInTheDocument()

    await user.type(password, 'secret-pass')
    await user.click(submit)

    expect(onLogin).toHaveBeenCalledWith({ password: 'secret-pass', access_token: 'tok-123' })
  })
})
