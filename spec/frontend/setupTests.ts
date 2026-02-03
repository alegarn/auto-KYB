import { vi } from 'vitest'

// Mock window.matchMedia for responsive components
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query) => ({
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

// Mock SvelteKit `$app/stores` `page` store so components can read `$page` in tests
import { readable } from 'svelte/store'
vi.mock('$app/stores', () => ({
  page: readable({
    url: new URL('http://localhost/'),
    params: {},
    route: { id: null },
    status: 200,
    error: null,
    form: null,
    stuff: null,
    session: null,
    flash: {},
  }),
}))

// Ensure `@inertiajs/svelte` provides a `page` store for components that use `$page`
vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte')
  return {
    ...(actual as any),
    page: readable({
      url: new URL('http://localhost/'),
      params: {},
      route: { id: null },
      status: 200,
      error: null,
      form: null,
      stuff: null,
      session: null,
      flash: {},
    }),
  }
})
