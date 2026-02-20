import { flushSync, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import RegistrationsNew from '../../../../app/frontend/pages/registrations/new.svelte'
import { mockPageProps } from '../../mocks/inertia'
import { mountPage } from '../helpers/renderPage'

const mount = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  mountPage({ pageName: 'registrations/new', component, props: options.props ?? {} })

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Registrations new mounts and shows account heading', () => {
  const component: any = mount(RegistrationsNew as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('Create a Quick KYB Account')

  unmount(component)
})
