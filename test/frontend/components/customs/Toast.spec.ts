import { test, expect } from 'vitest'
import { render, screen } from '@testing-library/svelte'
import Toast from '../../../../app/frontend/components/customs/Toast.svelte'

test('Toast component renders message and type', async () => {
  render(Toast, { props: { message: 'Client updated', type: 'notice' } })
  expect(await screen.findByText(/Client\s*updated/)).toBeInTheDocument()
})
