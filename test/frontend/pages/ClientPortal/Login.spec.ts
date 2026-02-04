import { render, screen } from '@testing-library/svelte'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, beforeEach, vi } from 'vitest'

import Login from '../../../../app/frontend/pages/ClientPortal/Login.svelte'

describe('ClientPortal/Login', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders password input and submit button and emits login event', async () => {
    const user = userEvent.setup()
    const onLogin = vi.fn()
    render(Login, { access_token: 'tok-123', onLogin })

    const password = screen.getByLabelText(/password/i)
    expect(password).toBeInTheDocument()

    const submit = screen.getByRole('button', { name: /login/i })
    expect(submit).toBeInTheDocument()

    await user.type(password, 'secret-pass')
    await user.click(submit)

    expect(onLogin).toHaveBeenCalledWith({ password: 'secret-pass', access_token: 'tok-123' })
  })
})
