import { flushSync, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import InertiaExample from '../../../../app/frontend/pages/inertia_example/index.svelte'
import { mountPage } from '../helpers/renderPage'

const mount = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  mountPage({ pageName: 'inertia_example/index', component, props: options.props ?? {} })

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Inertia example mounts and shows versions and button', () => {
  const props = { rails_version: '7.0', rack_version: '2.2', ruby_version: '3.1', inertia_rails_version: '1.0' }
  const component: any = mount(InertiaExample as any, { target: document.body, props })

  expect(document.body.innerHTML).toContain('Click me')
  expect(document.body.innerHTML).toContain('Inertia Rails version')

  unmount(component)
})
