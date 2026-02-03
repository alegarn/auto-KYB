import { flushSync, mount, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import SessionsNew from '../../../../app/frontend/pages/sessions/new.svelte'
import { mockPageProps } from '../../mocks/inertia'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Sessions new mounts and shows sign in heading', () => {
  const component: any = mount(SessionsNew as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('Sign In to Quick KYB')

  unmount(component)
})
