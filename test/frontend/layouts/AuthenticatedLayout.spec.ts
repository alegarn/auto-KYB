import { vi, test, expect, beforeEach, afterEach } from 'vitest'
import { cleanup } from '@testing-library/svelte'
import { mount, unmount } from 'svelte'

const { pageStore } = vi.hoisted(() => {
  let value: any = { url: '/dashboard', props: { session_id: 'test-session', crm_transfer_signals: null } }
  const subs = new Set<Function>()
  return {
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

import AuthenticatedLayout from '../../../app/frontend/layouts/AuthenticatedLayout.svelte'

beforeEach(() => {
  document.body.innerHTML = ''
  pageStore.set({
    url: '/dashboard',
    props: { session_id: 'test-session', crm_transfer_signals: null },
  })
})

afterEach(() => cleanup())

test('renders a global toast when crm_transfer_signals.toast is present', () => {
  pageStore.set({
    url: '/dashboard',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: {
        unread_failed_count: 2,
        unread_retryable_count: 1,
        latest_unread_failure_at: '2026-03-20T00:00:00Z',
        toast: { type: 'alert', message: '2 CRM transfers failed', href: '/crm_transfers' },
      },
    },
  })
  const component = mount(AuthenticatedLayout as any, { target: document.body })
  const toasts = document.querySelectorAll('[role="status"]')
  const crmToast = Array.from(toasts).find(el => el.textContent?.includes('CRM transfers failed'))
  expect(crmToast).toBeTruthy()
  expect(crmToast!.textContent).toContain('View transfers')
  const link = crmToast!.querySelector('a')
  expect(link).not.toBeNull()
  expect(link!.getAttribute('href')).toBe('/crm_transfers')
  unmount(component)
})

test('does not render the global toast when crm_transfer_signals.toast is null', () => {
  pageStore.set({
    url: '/dashboard',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: {
        unread_failed_count: 0,
        unread_retryable_count: 0,
        latest_unread_failure_at: null,
        toast: null,
      },
    },
  })
  const component = mount(AuthenticatedLayout as any, { target: document.body })
  const toasts = document.querySelectorAll('[role="status"]')
  const crmToast = Array.from(toasts).find(el => el.textContent?.includes('CRM transfers failed'))
  expect(crmToast).toBeFalsy()
  unmount(component)
})

test('does not render the global toast while already on /crm_transfers', () => {
  pageStore.set({
    url: '/crm_transfers',
    props: {
      session_id: 'test-session',
      crm_transfer_signals: {
        unread_failed_count: 2,
        unread_retryable_count: 1,
        latest_unread_failure_at: '2026-03-20T00:00:00Z',
        toast: { type: 'alert', message: '2 CRM transfers failed', href: '/crm_transfers' },
      },
    },
  })
  const component = mount(AuthenticatedLayout as any, { target: document.body })
  const toasts = document.querySelectorAll('[role="status"]')
  const crmToast = Array.from(toasts).find(el => el.textContent?.includes('CRM transfers failed'))
  expect(crmToast).toBeFalsy()
  unmount(component)
})
