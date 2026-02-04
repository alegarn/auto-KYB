import { vi } from 'vitest'

// Mock page props
export const mockPageProps = {
  url: '/dashboard',
  props: {
    user: { id: '1', email: 'test@example.com', name: 'Test User' },
    session_id: 'test-session-123',
    recent_forms: [],
    forms: [],
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
      recent_forms: [],
      forms: [],
      errors: null,
      flash: {}
    },
    component: 'Dashboard',
    version: '1.0'
  })
}

// Mock @inertiajs/svelte module for tests
vi.mock('@inertiajs/svelte', () => ({
  page: mockPage,
  // Provide simple functional stubs that Svelte can call during render
  Link: (props: any) => ({ $$render: () => `<a href="${props?.href ?? '#'}">${props?.children ?? ''}</a>` }),
  Form: (props: any) => ({ $$render: () => `<form>${props?.children ?? ''}</form>` }),
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
}))
