import { vi } from 'vitest'

// Mock page props
export const mockPageProps = {
  url: '/dashboard',
  props: {
    user: { id: '1', email: 'test@example.com', name: 'Test User' },
    session_id: 'test-session-123',
    clients: [
      { id: '1', name: 'Client One', status: 'active', updated_at: '2024-01-01' },
      { id: '2', name: 'Client Two', status: 'active', updated_at: '2024-01-02' },
      { id: '3', name: 'Client Three', status: 'pending', updated_at: '2024-01-03' },
      { id: '4', name: 'Client Four', status: 'active', updated_at: '2024-01-04' },
      { id: '5', name: 'Client Five', status: 'inactive', updated_at: '2024-01-05' }
    ],
    recent_forms: [],
    onboarding: undefined,
    forms: [],
    meta: { page: 1, per_page: 10, total_count: 5 },
    stats: { total_clients: 5, validated_clients: 1, active_clients: 3, linked_clients: 1 },
    errors: null,
    flash: {}
  },
  component: 'Dashboard',
  version: '1.0'
}

// Mock Inertia module helpers
export const mockInertia = vi.fn()
export const mockVisit = vi.fn()
export const mockForm = vi.fn()

let pageSubscribers: Function[] = []

export const mockPage = {
  subscribe: (fn: Function) => {
    pageSubscribers.push(fn)
    // Provide the store value as the `props` object so components expecting `$page.<prop>` work
    fn(mockPageProps.props)
    return () => {
      pageSubscribers = pageSubscribers.filter(s => s !== fn)
    }
  },
  get props() {
    return mockPageProps.props
  },
  get url() {
    return mockPageProps.url
  },
  get component() {
    return mockPageProps.component
  }
}

export function updatePageProps(updates: Partial<typeof mockPageProps>) {
  Object.assign(mockPageProps, updates)
  pageSubscribers.forEach(fn => fn(mockPageProps.props))
}

export function resetPageProps() {
  Object.assign(mockPageProps, {
    url: '/dashboard',
    props: {
      user: { id: '1', email: 'test@example.com', name: 'Test User' },
      session_id: 'test-session-123',
      clients: [
        { id: '1', name: 'Client One', status: 'active', updated_at: '2024-01-01' },
        { id: '2', name: 'Client Two', status: 'active', updated_at: '2024-01-02' },
        { id: '3', name: 'Client Three', status: 'pending', updated_at: '2024-01-03' },
        { id: '4', name: 'Client Four', status: 'active', updated_at: '2024-01-04' },
        { id: '5', name: 'Client Five', status: 'inactive', updated_at: '2024-01-05' }
      ],
      recent_forms: [],
      onboarding: undefined,
      forms: [],
      meta: { page: 1, per_page: 10, total_count: 5 },
      stats: { total_clients: 5, validated_clients: 1, active_clients: 3, linked_clients: 1 },
      errors: null,
      flash: {}
    },
    component: 'Dashboard',
    version: '1.0'
  })
}

// Mock @inertiajs/svelte module for tests
vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte')

  return {
    ...actual as any,
    page: mockPage,
    // Preserve actual Form and Link components so they render properly with Svelte slots
    inertia: mockInertia,
    visit: mockVisit,
    useForm: () => ({
      data: {},
      errors: {},
      processing: false,
      progress: null,
      hasErrors: false,
      clearErrors: vi.fn(),
      reset: vi.fn(),
      submit: vi.fn(),
      transform: vi.fn(),
      setDefaults: vi.fn()
    }),
    router: {
      visit: mockVisit,
      reload: vi.fn(),
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn()
    }
  }
})
