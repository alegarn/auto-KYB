import { vi } from 'vitest';
import { writable } from 'svelte/store';

// polyfill window.matchMedia for tests
if (typeof window !== 'undefined' && !window.matchMedia) {
  // @ts-ignore
  window.matchMedia = (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  });
}

// Note: specific tests provide their own `@inertiajs/svelte` mocks

// Provide a default mock for `@inertiajs/svelte` so components imported
// before test-level mocks won't fail. Individual tests can override this.
vi.mock('@inertiajs/svelte', () => {
  const mockPageProps = {
    url: '/dashboard',
    props: { user: { id: '1', email: 'test@example.com', name: 'Test User' }, session_id: null, recent_forms: [], forms: [], errors: null, flash: {} },
    component: 'Dashboard',
    version: '1.0'
  };

  const page = {
    subscribe: (fn: Function) => {
      fn(mockPageProps.props);
      return () => {}
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
  };

  const mockInertia = vi.fn();
  const mockVisit = vi.fn();

  return {
    page,
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
  };
});
