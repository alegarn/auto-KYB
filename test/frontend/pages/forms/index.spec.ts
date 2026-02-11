import { mount, tick, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import FormsIndex from '../../../../app/frontend/pages/forms/index.svelte'
import { mockPageProps, resetPageProps, updatePageProps } from '../../mocks/inertia'
import { screen } from '@testing-library/svelte'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
  resetPageProps()
})

test('Forms index mounts and shows My Forms header', () => {
  const component: any = mount(FormsIndex as any, { target: document.body, props: { ...mockPageProps.props } })

  expect(document.body.innerHTML).toContain('My Forms')

  unmount(component)
})


test('shows toast when page.flash.toast is set', async () => {
  const props = {
    user: { email: 'u@e' },
    session_id: 's',
    forms: [{ id: '1', name: 'A', status: 'draft', updated_at: 'now' }],
    children: undefined,
  }

  const component: any = mount(FormsIndex as any, { target: document.body, props })

  // set the flash on the mocked `page` store
  updatePageProps({ props: { ...mockPageProps.props, flash: { toast: { message: 'Form deleted', type: 'notice' } } } })
  await tick()

  // wait for the toast to appear (allow possible line-breaks/whitespace)
  expect(await screen.findByText(/Form\s*deleted/)).toBeInTheDocument()

  unmount(component)
})