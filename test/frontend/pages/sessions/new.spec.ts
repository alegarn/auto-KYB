import { flushSync, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import { mockPageProps } from '../../mocks/inertia'
import SessionsNew from '../../../../app/frontend/pages/sessions/new.svelte'
import { mountPage } from '../helpers/renderPage'

const mount = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  mountPage({ pageName: 'sessions/new', component, props: options.props ?? {} })

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Sessions new mounts and shows sign in heading', () => {
  const component: any = mount(SessionsNew as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('Sign In to Quick KYB')

  unmount(component)
})
