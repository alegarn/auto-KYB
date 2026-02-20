import { flushSync, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'

import { mockPageProps } from '../../mocks/inertia'
import { mountPage } from '../helpers/renderPage'
import Dashboard from '../../../../app/frontend/pages/Dashboard/Dashboard.svelte'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('renders with Inertia page props and displays user email', () => {
  const component: any = mountPage({
    pageName: 'Dashboard/Dashboard',
    component: Dashboard,
    props: { ...mockPageProps.props },
  })

  expect(document.body.textContent).toMatch(/test@example.com/i)

  unmount(component)
})

test('has navigation links with correct hrefs', () => {
  const component: any = mountPage({
    pageName: 'Dashboard/Dashboard',
    component: Dashboard,
    props: { ...mockPageProps.props },
  })

  const links = Array.from(document.body.querySelectorAll('a'))
  const newFormLink = links.find((el) => el.getAttribute('href') === '/forms/new')
  expect(newFormLink).not.toBeNull()

  unmount(component)
})

test('displays client counts after mount timeout', async () => {
  vi.useFakeTimers()

  const component: any = mountPage({
    pageName: 'Dashboard/Dashboard',
    component: Dashboard,
    props: { ...mockPageProps.props },
  })

  // allow onMount to schedule tasks
  await Promise.resolve()
  // advance timers to trigger onMount setTimeout in Dashboard
  vi.runAllTimers()
  // allow any microtasks to complete and flush Svelte updates
  await Promise.resolve()
  flushSync()

  expect(document.body.textContent).toMatch(/\b5\b/)

  unmount(component)
  vi.useRealTimers()
})
