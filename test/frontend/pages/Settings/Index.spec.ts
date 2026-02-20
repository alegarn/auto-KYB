import { flushSync, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import Settings from '../../../../app/frontend/pages/Settings/Index.svelte'
import { mockPageProps } from '../../mocks/inertia'
import { mountPage } from '../helpers/renderPage'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Settings mounts and shows Settings heading', () => {
  const component: any = mountPage({
    pageName: 'Settings/Index',
    component: Settings,
    props: { ...mockPageProps.props },
  })

  expect(document.body.innerHTML).toContain('Settings')

  unmount(component)
})
