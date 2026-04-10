import { render, fireEvent, waitFor } from '@testing-library/svelte'
import Pricing from '/components/customs/pricing.svelte'
import { expect, it, vi } from 'vitest'

it('shows spinner and disables button while subscribing to the Basic plan', async () => {
  let resolveCheckoutRequest: ((value: { json: () => Promise<{ url: null }> }) => void) | undefined
  const fakeFetch = vi.fn(() => new Promise((resolve) => {
    resolveCheckoutRequest = resolve
  }))
  globalThis.fetch = fakeFetch as any

  const { container } = render(Pricing, { props: { customer_email: 'test@example.com' } })
  const basicCard = container.querySelector('[data-slot="card"]')
  const basicButton = basicCard?.querySelector('button[data-slot="button"]') as HTMLButtonElement

  await fireEvent.click(basicButton)

  await waitFor(() => expect(basicButton).toBeDisabled())

  await waitFor(() => expect(container.querySelector('.animate-spin')).toBeTruthy())

  resolveCheckoutRequest?.({ json: async () => ({ url: null }) })

  await waitFor(() => expect(basicButton).not.toBeDisabled())
  await waitFor(() => expect(container.querySelector('.animate-spin')).toBeFalsy())
})
