import { flushSync, mount, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import Settings from '../../../../app/frontend/pages/Settings/Index.svelte'
import { mockPageProps } from '../../mocks/inertia'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Settings mounts and shows Settings heading', () => {
  const component: any = mount(Settings as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('Settings')

  unmount(component)
})
