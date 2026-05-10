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
  const component: any = mount(SessionsNew as any, { props: { ...mockPageProps.props } })
  const emailForm = document.querySelector<HTMLFormElement>('form[action="/sign_in"]')
  const googleForm = document.querySelector<HTMLFormElement>('form[action="/auth/google_oauth2"]')
  const googleButton = Array.from(document.querySelectorAll<HTMLButtonElement>('button')).find(
    (button) => button.textContent?.includes('Sign in with Google'),
  )

  expect(document.body.innerHTML).toContain('Sign In to Quick KYB')
  expect(emailForm).not.toBeNull()
  expect(googleForm).not.toBeNull()
  expect(emailForm?.contains(googleForm as HTMLFormElement)).toBe(false)
  expect(googleButton?.closest('form')).toBe(googleForm)

  unmount(component)
})
