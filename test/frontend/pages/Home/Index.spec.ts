import { flushSync, unmount } from 'svelte'
import { screen } from '@testing-library/svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import { mockPageProps, resetPageProps, updatePageProps } from '../../mocks/inertia'
import Home from '../../../../app/frontend/pages/Home/Index.svelte'
import { mountPage } from '../helpers/renderPage'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
  resetPageProps()
  updatePageProps({
    url: '/',
    component: 'Home/Index',
  })
})

function guestPageProps() {
  return {
    ...mockPageProps.props,
    user: {
      id: 'legacy-user',
      email: 'legacy@example.com',
    },
    auth: null,
    public_auth_cta: null,
    session_id: null,
    flash: {},
  } as any
}

function authenticatedPageProps() {
  return {
    ...mockPageProps.props,
    user: null,
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
    public_auth_cta: {
      label: 'Dashboard',
      href: '/dashboard',
    },
    session_id: 'session-123',
    flash: {},
  } as any
}

test('Home mounts and displays guest hero actions', () => {
  vi.useFakeTimers()

  updatePageProps({
    props: guestPageProps(),
  })

  const component: any = mountPage({
    pageName: 'Home/Index',
    component: Home,
    props: {},
  })

  // advance timers to allow deferred image load effect
  vi.runAllTimers()
  flushSync()

  expect(document.body.innerHTML).toContain('Quick KYB')
  expect(screen.getByRole('link', { name: 'Start Onboarding' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Request a demo' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Logout' })).not.toBeInTheDocument()

  unmount(component)
  vi.useRealTimers()
})

test('Home keeps the hero public even when shared auth state is present', () => {
  vi.useFakeTimers()

  updatePageProps({
    props: authenticatedPageProps(),
  })

  const component: any = mountPage({
    pageName: 'Home/Index',
    component: Home,
    props: {},
  })

  vi.runAllTimers()
  flushSync()

  expect(screen.getByRole('link', { name: 'Start Onboarding' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Request a demo' })).toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Dashboard' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Logout' })).not.toBeInTheDocument()

  unmount(component)
  vi.useRealTimers()
})
