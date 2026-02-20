import { createInertiaApp, type ResolvedComponent } from '@inertiajs/svelte'
import { mount } from 'svelte'
import AuthenticatedLayout from '../layouts/AuthenticatedLayout.svelte'

const PUBLIC_PAGE_PREFIXES = [
  'ClientPortal/',
  'Home/',
  'sessions/',
  'registrations/',
  'inertia_example/',
  'Clients/PasswordReveal',
]

function isPublicPage(name: string): boolean {
  return PUBLIC_PAGE_PREFIXES.some((prefix) => name.startsWith(prefix))
}

createInertiaApp({
  resolve: async (name) => {
    const pages = import.meta.glob<ResolvedComponent>('../pages/**/*.svelte', {
      eager: false,
    })
    const page = pages[`../pages/${name}.svelte`]
    if (!page) {
      console.error(`Missing Inertia page component: '${name}.svelte'`)
    }

    const resolved = await page()

    return {
      default: resolved.default,
      layout: resolved.layout || (isPublicPage(name) ? undefined : AuthenticatedLayout),
    } as ResolvedComponent
  },

  setup({ el, App, props }) {
    if (el) {
      mount(App, { target: el, props })
    } else {
      console.error(
        'Missing root element.\n\n' +
          'If you see this error, it probably means you load Inertia.js on non-Inertia pages.\n' +
          'Consider moving <%= vite_typescript_tag "inertia" %> to the Inertia-specific layout instead.',
      )
    }
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
    },
    future: {
      useScriptElementForInitialPage: true,
      useDataInertiaHeadAttribute: true,
      useDialogForErrorModal: true,
      preserveEqualProps: true,
    },
  },
})
