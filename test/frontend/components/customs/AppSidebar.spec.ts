import { vi, test, expect, beforeEach, afterEach } from 'vitest'
import { cleanup, screen } from '@testing-library/svelte'
import userEvent from '@testing-library/user-event'
import { mount, unmount, flushSync } from 'svelte'

const { pageStore, sharedAuth } = vi.hoisted(() => {
  const sharedAuth = {
    user: {
      id: '1',
      email: 'test@example.com',
      onboarding_completed: true,
      plan: 'pro',
      crm_auto_sync_on_portal_submit: false,
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
  }

  let value: any = { url: '/dashboard', props: { session_id: 'test-session', crm_transfer_signals: null, auth: sharedAuth } }
  const subs = new Set<Function>()
  return {
    sharedAuth,
    pageStore: {
      subscribe(fn: Function) {
        subs.add(fn)
        fn(value)
        return () => { subs.delete(fn) }
      },
      set(v: any) {
        value = v
        subs.forEach(fn => fn(value))
      },
    },
  }
})

vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte')
  return {
    ...(actual as any),
    page: pageStore,
    router: {
      visit: vi.fn(),
      reload: vi.fn(),
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn(),
      flash: vi.fn(),
      replace: vi.fn(),
    },
  }
})

import AppSidebarTestHost from './AppSidebarTestHost.svelte'

beforeEach(() => {
  document.body.innerHTML = ''
  pageStore.set({
    url: '/dashboard',
    props: { session_id: 'test-session', crm_transfer_signals: null, auth: sharedAuth },
  })
})

afterEach(() => cleanup())

test('renders the CRM Transfers link without a badge when unread_failed_count is zero', () => {
  pageStore.set({
    url: '/dashboard',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: { unread_failed_count: 0, unread_retryable_count: 0, latest_unread_failure_at: null, toast: null },
      auth: sharedAuth,
    },
  })
  const component = mount(AppSidebarTestHost as any, { target: document.body })
  expect(document.body.textContent).toContain('CRM Transfers')
  expect(document.querySelector('[data-sidebar="menu-badge"]')).toBeNull()
  unmount(component)
})

test('renders a badge next to CRM Transfers when unread_failed_count is positive', () => {
  pageStore.set({
    url: '/dashboard',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: { unread_failed_count: 3, unread_retryable_count: 1, latest_unread_failure_at: null, toast: null },
      auth: sharedAuth,
    },
  })
  const component = mount(AppSidebarTestHost as any, { target: document.body })
  const badge = document.querySelector('[data-sidebar="menu-badge"]')
  expect(badge).not.toBeNull()
  expect(badge!.textContent).toContain('3')
  unmount(component)
})

test('renders 99+ when unread_failed_count exceeds the visual cap', () => {
  pageStore.set({
    url: '/dashboard',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: { unread_failed_count: 150, unread_retryable_count: 0, latest_unread_failure_at: null, toast: null },
      auth: sharedAuth,
    },
  })
  const component = mount(AppSidebarTestHost as any, { target: document.body })
  const badge = document.querySelector('[data-sidebar="menu-badge"]')
  expect(badge).not.toBeNull()
  expect(badge!.textContent).toContain('99+')
  unmount(component)
})

test('keeps the CRM Transfers link active when the current page is within /crm_transfers', () => {
  pageStore.set({
    url: '/crm_transfers',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: null,
      auth: sharedAuth,
    },
  })
  const component = mount(AppSidebarTestHost as any, { target: document.body })
  const activeButtons = document.querySelectorAll('[data-active="true"]')
  const crmButton = Array.from(activeButtons).find(el => el.textContent?.includes('CRM Transfers'))
  expect(crmButton).toBeTruthy()
  unmount(component)
})

test('does not open the detailed onboarding sheet from a hidden shared onboarding payload and still allows reset', async () => {
  const user = userEvent.setup()

  pageStore.set({
    url: '/dashboard',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: null,
      onboarding: { visible: false },
      auth: sharedAuth,
    },
  })

  const component = mount(AppSidebarTestHost as any, { target: document.body })

  expect(screen.getByRole('button', { name: 'Detailed Onboarding' })).toBeDisabled()

  await user.click(screen.getByRole('button', { name: 'Reset Onboarding' }))

  expect(screen.getByText('Reset Onboarding Guide')).toBeInTheDocument()
  expect(screen.queryByText('Detailed onboarding')).not.toBeInTheDocument()

  unmount(component)
})
