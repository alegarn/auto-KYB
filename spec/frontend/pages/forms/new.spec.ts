import { flushSync, mount, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import NewForm from '../../../../app/frontend/pages/forms/new.svelte'
import { mockPageProps } from '../../mocks/inertia'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('New form mounts and shows Create Form heading', () => {
  const component: any = mount(NewForm as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('Create Form')

  unmount(component)
})
