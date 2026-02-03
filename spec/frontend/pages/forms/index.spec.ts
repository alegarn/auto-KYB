import { flushSync, mount, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import FormsIndex from '../../../../app/frontend/pages/forms/index.svelte'
import { mockPageProps } from '../../mocks/inertia'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Forms index mounts and shows My Forms header', () => {
  const component: any = mount(FormsIndex as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('My Forms')

  unmount(component)
})
