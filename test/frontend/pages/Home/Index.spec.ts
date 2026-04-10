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

test('Home shows dashboard and logout actions for authenticated users', () => {
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

  expect(screen.getByRole('link', { name: 'Dashboard' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Logout' })).toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Start Onboarding' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Request a demo' })).not.toBeInTheDocument()

  unmount(component)
  vi.useRealTimers()
})
