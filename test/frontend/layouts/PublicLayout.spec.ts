import { cleanup, render, screen } from '@testing-library/svelte'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'

import { mockPageProps, resetPageProps, updatePageProps } from '../mocks/inertia'
import PublicLayout from '../../../app/frontend/layouts/PublicLayout.svelte'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
  resetPageProps()
  updatePageProps({
    url: '/',
    component: 'Home/Index',
  })
})

afterEach(() => cleanup())

function guestPageProps() {
  return {
    ...mockPageProps.props,
    user: {
      id: 'legacy-user',
      email: 'legacy@example.com',
    },
    auth: null,
    public_auth_cta: null,
    session_id: null,
    flash: {},
  } as any
}

function authenticatedPageProps(label = 'Dashboard', href = '/dashboard') {
  return {
    ...mockPageProps.props,
    user: null,
    auth: null,
    public_auth_cta: {
      label,
      href,
    },
    session_id: 'session-123',
    flash: {},
  } as any
}

test('shows guest navigation actions on the public landing page', () => {
  updatePageProps({
    props: guestPageProps(),
  })

  render(PublicLayout)

  expect(screen.getByRole('link', { name: 'Login' })).toBeInTheDocument()
  expect(screen.getByRole('link', { name: 'Sign Up' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Logout' })).not.toBeInTheDocument()
})

test('shows the shared authenticated CTA and logout when the visitor already has a session', () => {
  updatePageProps({
    props: authenticatedPageProps(),
  })

  render(PublicLayout)

  expect(screen.getByRole('link', { name: 'Dashboard' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Logout' })).toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Login' })).not.toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Sign Up' })).not.toBeInTheDocument()
})

test('renders alternative server-owned CTA labels without reading auth directly', () => {
  updatePageProps({
    props: authenticatedPageProps('Resume Subscription', '/sign_up'),
  })

  render(PublicLayout)

  expect(screen.getByRole('link', { name: 'Resume Subscription' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Logout' })).toBeInTheDocument()
})