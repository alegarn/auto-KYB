import { render, fireEvent, waitFor } from '@testing-library/svelte'
import Pricing from '/components/customs/pricing.svelte'
import { vi } from 'vitest'

it('shows spinner and disables button when subscribing to Basic plan', async () => {
  const fakeFetch = vi.fn().mockResolvedValue({ json: async () => ({ url: null }) })
  globalThis.fetch = fakeFetch as any

  const { container } = render(Pricing, { props: { customer_email: 'test@example.com' } })
  const basicCard = container.querySelector('[data-slot="card"]')
  const basicButton = basicCard?.querySelector('button[data-slot="button"]') as HTMLButtonElement

  await fireEvent.click(basicButton)

  await waitFor(() => expect(basicButton).toBeDisabled())

  await waitFor(() => expect(container.querySelector('.animate-spin')).toBeTruthy())
})
