import { test, expect } from 'vitest'
import { render, screen } from '@testing-library/svelte'
import Toast from '../../../../app/frontend/components/customs/Toast.svelte'

test('Toast component renders message and type', async () => {
  render(Toast, { props: { message: 'Client updated', type: 'notice' } })
  expect(await screen.findByText(/Client\s*updated/)).toBeInTheDocument()
})

test('renders an action link when actionHref and actionLabel are provided', () => {
  render(Toast, { props: { message: 'Transfer failed', type: 'alert', actionHref: '/crm_transfers', actionLabel: 'View' } })
  const link = screen.getByRole('link', { name: 'View' })
  expect(link).toBeInTheDocument()
  expect(link).toHaveAttribute('href', '/crm_transfers')
})

test('does not render an action link when no action props are provided', () => {
  render(Toast, { props: { message: 'Success', type: 'notice' } })
  expect(screen.queryByRole('link')).not.toBeInTheDocument()
})
