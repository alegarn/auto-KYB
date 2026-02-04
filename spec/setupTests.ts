import { vi, expect } from 'vitest'
import * as matchers from '@testing-library/jest-dom/matchers'
import { readable } from 'svelte/store'

expect.extend(matchers)

// Mock window.matchMedia for responsive components using Vitest's vi.fn
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

// Mock IntersectionObserver for lazy loading
;(global as any).IntersectionObserver = class IntersectionObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  takeRecords() {
    return []
  }
  unobserve() {}
}

// Mock requestIdleCallback for lazy loading
;(global as any).requestIdleCallback = (callback: any) => {
  return setTimeout(() => callback({ didTimeout: false }), 1)
}

;(global as any).cancelIdleCallback = (id: number) => {
  clearTimeout(id)
}

// Provide a default mock for `@inertiajs/svelte` so components imported
// before test-level mocks won't fail. Individual tests can override this.
vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte')

  const mockPage = readable({
    url: new URL('http://localhost/'),
    params: {},
    route: { id: null },
    status: 200,
    error: null,
    form: null,
    stuff: null,
    session: null,
    flash: {},
  })

  const mockInertia = vi.fn()
  const mockVisit = vi.fn()

  return {
    ...(actual as any),
    page: mockPage,
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
      setDefaults: vi.fn(),
    }),
    router: {
      visit: mockVisit,
      reload: vi.fn(),
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn(),
    },
  }
})
