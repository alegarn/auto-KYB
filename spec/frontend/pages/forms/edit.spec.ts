import { mount, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import Edit from '../../../../app/frontend/pages/forms/edit.svelte'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Edit form mounts and shows heading', () => {
  const fakeForm = { id: '1', name: 'Test Form', description: 'desc', form_fields: [] }
  const component: any = mount(Edit as any, { target: document.body, props: { form: fakeForm } })

  expect(document.body.innerHTML).toContain('Edit Form')

  unmount(component)
})
