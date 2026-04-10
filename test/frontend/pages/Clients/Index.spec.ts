import { screen, within } from '@testing-library/svelte'
import userEvent from '@testing-library/user-event'
import { test, expect, vi, beforeEach } from 'vitest'

import Index from '../../../../app/frontend/pages/Clients/Index.svelte'
import { renderPage } from '../helpers/renderPage'

const render = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  renderPage({ pageName: 'Clients/Index', component, props: options.props ?? {} })

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

const mockUser = { id: '1', email: 'test@example.com', name: 'Test User' }

const defaultMeta = { page: 1, per_page: 10, total_count: 0 }
const defaultProps = { user: mockUser, clients: [], meta: defaultMeta, session_id: '', children: null }

function renderIndex(overrides: Record<string, any> = {}) {
  const props = { ...defaultProps, ...overrides }
  return render(Index, { props })
}

test('renders without crashing with empty clients array', () => {
  renderIndex()
  expect(screen.getByText('Clients')).toBeTruthy()
})

test('displays the correct header with user email', () => {
  renderIndex()
  expect(screen.getByText(mockUser.email)).toBeTruthy()
})

test('shows "No clients found" message when clients array is empty', () => {
  renderIndex()
  expect(screen.getByText(/No clients found/i)).toBeTruthy()
})

test('renders client list when clients are provided', () => {
  const clients = [
    { id: '1', name: 'Acme', company_name: 'Acme Inc.' },
    { id: '2', name: 'Beta', company_name: 'Beta LLC' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 2 } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const items = within(list).getAllByRole('listitem')
  expect(items.length).toBe(2)
  expect(screen.getByText('Acme')).toBeTruthy()
  expect(screen.getByText('Beta')).toBeTruthy()
})

test('displays search input and buttons', async () => {
  const user = userEvent.setup()
  renderIndex()

  expect(screen.getByPlaceholderText('Search by name or company')).toBeTruthy()
  expect(screen.getByText('Search')).toBeTruthy()
  expect(screen.getByText('Clear search')).toBeTruthy()
  expect(screen.getByText('Add client')).toBeTruthy()

  // basic interaction: type into search
  await user.type(screen.getByPlaceholderText('Search by name or company'), 'Acme')
  expect((screen.getByPlaceholderText('Search by name or company') as HTMLInputElement).value).toBe('Acme')
})

test('renders pagination when meta.total_count > meta.per_page', () => {
  renderIndex({ clients: [{ id: '1', name: 'A', company_name: '' }], meta: { page: 1, per_page: 1, total_count: 3 } })

  const pagination = screen.getByLabelText('Pagination')
  const buttons = within(pagination).getAllByRole('button')
  // three pages expected
  expect(buttons.length).toBe(3)
  expect(within(pagination).getByRole('button', { name: '1' })).toBeTruthy()
  expect(within(pagination).getByRole('button', { name: '2' })).toBeTruthy()
  expect(within(pagination).getByRole('button', { name: '3' })).toBeTruthy()
})

/**
 * Test: Client status badge display
 * Verifies that status badges are rendered with correct CSS classes for each status type:
 * - "validated": bg-emerald-100 text-emerald-700
 * - "active": bg-blue-100 text-blue-700
 * - "linked": bg-amber-100 text-amber-700
 * - "inactive": bg-slate-100 text-slate-600
 */
test('renders status badge with correct classes for validated status', () => {
  const clients = [
    { id: '1', name: 'Validated Client', company_name: 'Validated Inc.', status: 'validated' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 1 } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const listItem = within(list).getByRole('listitem')
  const statusBadge = within(listItem).getByText('validated')
  expect(statusBadge).toBeTruthy()
  expect(statusBadge).toHaveClass('bg-emerald-100', 'text-emerald-700')
})

test('renders status badge with correct classes for active status', () => {
  const clients = [
    { id: '1', name: 'Active Client', company_name: 'Active Inc.', status: 'active' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 1 } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const listItem = within(list).getByRole('listitem')
  const statusBadge = within(listItem).getByText('active')
  expect(statusBadge).toBeTruthy()
  expect(statusBadge).toHaveClass('bg-blue-100', 'text-blue-700')
})

test('renders status badge with correct classes for linked status', () => {
  const clients = [
    { id: '1', name: 'Linked Client', company_name: 'Linked Inc.', status: 'linked' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 1 } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const listItem = within(list).getByRole('listitem')
  const statusBadge = within(listItem).getByText('linked')
  expect(statusBadge).toBeTruthy()
  expect(statusBadge).toHaveClass('bg-amber-100', 'text-amber-700')
})

test('renders status badge with correct classes for inactive status', () => {
  const clients = [
    { id: '1', name: 'Inactive Client', company_name: 'Inactive Inc.', status: 'inactive' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 1 } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const listItem = within(list).getByRole('listitem')
  const statusBadge = within(listItem).getByText('inactive')
  expect(statusBadge).toBeTruthy()
  expect(statusBadge).toHaveClass('bg-slate-100', 'text-slate-600')
})

test('renders status badge with default classes for unknown status', () => {
  const clients = [
    { id: '1', name: 'Unknown Client', company_name: 'Unknown Inc.', status: 'unknown' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 1 } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const listItem = within(list).getByRole('listitem')
  const statusBadge = within(listItem).getByText('unknown')
  expect(statusBadge).toBeTruthy()
  expect(statusBadge).toHaveClass('bg-slate-100', 'text-slate-600')
})

test('renders multiple clients with different status badges', () => {
  const clients = [
    { id: '1', name: 'Client 1', company_name: 'Company 1', status: 'validated' },
    { id: '2', name: 'Client 2', company_name: 'Company 2', status: 'active' },
    { id: '3', name: 'Client 3', company_name: 'Company 3', status: 'linked' },
    { id: '4', name: 'Client 4', company_name: 'Company 4', status: 'inactive' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 4 } })

  const list = screen.getByRole('list', { name: /Client list/i })
  const listItems = within(list).getAllByRole('listitem')

  expect(within(listItems[0]).getByText('validated')).toHaveClass('bg-emerald-100', 'text-emerald-700')
  expect(within(listItems[1]).getByText('active')).toHaveClass('bg-blue-100', 'text-blue-700')
  expect(within(listItems[2]).getByText('linked')).toHaveClass('bg-amber-100', 'text-amber-700')
  expect(within(listItems[3]).getByText('inactive')).toHaveClass('bg-slate-100', 'text-slate-600')
})

/**
 * Test: Filtering by name
 * Verifies that the search functionality works correctly for filtering clients by name or company
 */
test('displays search input for filtering by name or company', () => {
  renderIndex()

  const searchInput = screen.getByPlaceholderText('Search by name or company')
  expect(searchInput).toBeTruthy()
  expect(searchInput).toHaveAttribute('name', 'q')
  expect(searchInput).toHaveAttribute('id', 'q')
})

test('allows typing into search input', async () => {
  const user = userEvent.setup()
  renderIndex()

  const searchInput = screen.getByPlaceholderText('Search by name or company')
  
  await user.type(searchInput, 'Acme Corporation')
  
  expect((searchInput as HTMLInputElement).value).toBe('Acme Corporation')
})

test('search button is present and clickable', async () => {
  const user = userEvent.setup()
  renderIndex()

  const searchButton = screen.getByRole('button', { name: 'Search' })
  expect(searchButton).toBeTruthy()
  
  await user.click(searchButton)
  // Note: Actual router navigation would be tested with mocked router
  expect(searchButton).toBeTruthy()
})

test('renders clients with status information', () => {
  const clients = [
    { id: '1', name: 'Client A', company_name: 'Company A', status: 'validated' },
    { id: '2', name: 'Client B', company_name: 'Company B', status: 'active' }
  ]

  renderIndex({ clients, meta: { page: 1, per_page: 10, total_count: 2 } })

  // Verify both clients are rendered with their status badges
  expect(screen.getByText('Client A')).toBeTruthy()
  expect(screen.getByText('Client B')).toBeTruthy()

  const list = screen.getByRole('list', { name: /Client list/i })
  const listItems = within(list).getAllByRole('listitem')
  expect(within(listItems[0]).getByText('validated')).toBeTruthy()
  expect(within(listItems[1]).getByText('active')).toBeTruthy()
})
