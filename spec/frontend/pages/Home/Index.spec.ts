import { flushSync, mount, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import Home from '../../../../app/frontend/pages/Home/Index.svelte'
import { mockPageProps } from '../../mocks/inertia'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Home mounts and displays hero text', () => {
  vi.useFakeTimers()

  const component: any = mount(Home as any, { target: document.body, props: { ...mockPageProps.props } })

  // advance timers to allow deferred image load effect
  vi.runAllTimers()
  flushSync()

  expect(document.body.innerHTML).toContain('Fast KYC')

  unmount(component)
  vi.useRealTimers()
})
