import { cleanup, render, screen } from '@testing-library/svelte'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import { mockPageProps, resetPageProps, updatePageProps } from '../mocks/inertia'
import PublicLayout from '../../../app/frontend/layouts/PublicLayout.svelte'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
  resetPageProps()
  updatePageProps({
    url: '/',
    component: 'Home/Index',
  })
})

afterEach(() => cleanup())

function guestPageProps() {
  return {
    ...mockPageProps.props,
    auth: null,
    session_id: null,
    user: null,
    flash: {},
  } as any
}

function authenticatedPageProps() {
  return {
    ...mockPageProps.props,
    auth: {
      user: {
        id: '1',
        email: 'owner@example.com',
        onboarding_completed: true,
        plan: 'pro',
        crm_auto_sync_on_portal_submit: true,
      },
      subscription: {
        status: 'active',
        active: true,
        canceled_at: null,
      },
      features: {
        crm: {
          allowed: true,
          reason: 'allowed',
          plan_eligible: true,
          subscription_active: true,
          auto_sync_allowed: true,
        },
      },
    },
    session_id: 'session-123',
    flash: {},
  } as any
}

test('shows guest navigation actions on the public landing page', () => {
  updatePageProps({
    props: guestPageProps(),
  })

  render(PublicLayout)

  expect(screen.getByRole('link', { name: 'Login' })).toBeInTheDocument()
  expect(screen.getByRole('link', { name: 'Sign Up' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Logout' })).not.toBeInTheDocument()
})

test('shows dashboard and logout actions when the visitor already has a session', () => {
  updatePageProps({
    props: authenticatedPageProps(),
  })

  render(PublicLayout)

  expect(screen.getByRole('link', { name: 'Dashboard' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Logout' })).toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Login' })).not.toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Sign Up' })).not.toBeInTheDocument()
})