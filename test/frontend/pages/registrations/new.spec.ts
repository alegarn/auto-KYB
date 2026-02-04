import { flushSync, mount, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import RegistrationsNew from '../../../../app/frontend/pages/registrations/new.svelte'
import { mockPageProps } from '../../mocks/inertia'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Registrations new mounts and shows account heading', () => {
  const component: any = mount(RegistrationsNew as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('Create a Tailus UI Account')

  unmount(component)
})
