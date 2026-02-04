import { render, screen } from '@testing-library/svelte'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, beforeEach, vi } from 'vitest'

import FormResponse from '../../../../app/frontend/pages/ClientPortal/FormResponse.svelte'

describe('ClientPortal/FormResponse', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  const form = {
    id: 'f1',
    name: 'Test Form',
    form_fields: [
      { id: 'a', label: 'First Name', type: 'text', value: '' },
      { id: 'b', label: 'Age', type: 'number', value: null },
      { id: 'c', label: 'Birthday', type: 'date', value: null }
    ]
  }

  it('renders text, number and date fields and emits save with values', async () => {
    const user = userEvent.setup()
    const onSave = vi.fn()
    render(FormResponse, { form, onSave })

    expect(screen.getByLabelText(/first name/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/age/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/birthday/i)).toBeInTheDocument()

    // use callback prop for Svelte 5 compatibility

    await user.type(screen.getByLabelText(/first name/i), 'Alice')
    await user.type(screen.getByLabelText(/age/i), '30')
    await user.type(screen.getByLabelText(/birthday/i), '1990-01-01')

    const save = screen.getByRole('button', { name: /save/i })
    await user.click(save)

    expect(onSave).toHaveBeenCalledWith({ data: { a: 'Alice', b: 30, c: '1990-01-01' }, validate: false })
  })
})
