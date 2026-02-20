import { flushSync, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import Show from '../../../../app/frontend/pages/forms/show.svelte'
import { mountPage } from '../helpers/renderPage'

const mount = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  mountPage({ pageName: 'forms/show', component, props: options.props ?? {} })

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Show form with no fields displays placeholder message', () => {
  const fakeForm = { id: '1', name: 'Empty Form', description: 'desc', form_fields: [] }
  const component: any = mount(Show as any, { target: document.body, props: { form: fakeForm } })

  expect(document.body.innerHTML).toContain('This form has no fields yet')

  unmount(component)
})
