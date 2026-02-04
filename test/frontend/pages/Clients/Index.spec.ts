import { render, screen, within } from '@testing-library/svelte'
import userEvent from '@testing-library/user-event'
import { test, expect, vi, beforeEach } from 'vitest'

import Index from '../../../../app/frontend/pages/Clients/Index.svelte'

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

const mockUser = { id: '1', email: 'test@example.com', name: 'Test User' }

test('renders without crashing with empty clients array', () => {
  render(Index, { props: { user: mockUser, clients: [], meta: { page: 1, per_page: 10, total_count: 0 } } })
  expect(screen.getByText('Clients')).toBeTruthy()
})

test('displays the correct header with user email', () => {
  render(Index, { props: { user: mockUser, clients: [], meta: { page: 1, per_page: 10, total_count: 0 } } })
  expect(screen.getByText(mockUser.email)).toBeTruthy()
})

test('shows "No clients found" message when clients array is empty', () => {
  render(Index, { props: { user: mockUser, clients: [], meta: { page: 1, per_page: 10, total_count: 0 } } })
  expect(screen.getByText(/No clients found/i)).toBeTruthy()
})

test('renders client list when clients are provided', () => {
  const clients = [
    { id: '1', name: 'Acme', company_name: 'Acme Inc.' },
    { id: '2', name: 'Beta', company_name: 'Beta LLC' }
  ]

  render(Index, { props: { user: mockUser, clients, meta: { page: 1, per_page: 10, total_count: 2 } } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const items = within(list).getAllByRole('listitem')
  expect(items.length).toBe(2)
  expect(screen.getByText('Acme')).toBeTruthy()
  expect(screen.getByText('Beta')).toBeTruthy()
})

test('displays search input and buttons', async () => {
  const user = userEvent.setup()
  render(Index, { props: { user: mockUser, clients: [], meta: { page: 1, per_page: 10, total_count: 0 } } })

  expect(screen.getByPlaceholderText('Search by name or company')).toBeTruthy()
  expect(screen.getByText('Search')).toBeTruthy()
  expect(screen.getByText('Clear search')).toBeTruthy()
  expect(screen.getByText('Add client')).toBeTruthy()

  // basic interaction: type into search
  await user.type(screen.getByPlaceholderText('Search by name or company'), 'Acme')
  expect((screen.getByPlaceholderText('Search by name or company') as HTMLInputElement).value).toBe('Acme')
})

test('renders pagination when meta.total_count > meta.per_page', () => {
  render(Index, { props: { user: mockUser, clients: [{ id: '1', name: 'A', company_name: '' }], meta: { page: 1, per_page: 1, total_count: 3 } } })

  const pagination = screen.getByLabelText('Pagination')
  const buttons = within(pagination).getAllByRole('button')
  // three pages expected
  expect(buttons.length).toBe(3)
  expect(within(pagination).getByRole('button', { name: '1' })).toBeTruthy()
  expect(within(pagination).getByRole('button', { name: '2' })).toBeTruthy()
  expect(within(pagination).getByRole('button', { name: '3' })).toBeTruthy()
})
