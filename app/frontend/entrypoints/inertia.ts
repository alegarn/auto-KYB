import { createInertiaApp, type ResolvedComponent } from '@inertiajs/svelte'
import { mount } from 'svelte'
import AuthenticatedLayout from '../layouts/AuthenticatedLayout.svelte'
import PublicLayout from '../layouts/PublicLayout.svelte'
import { isNoSidebarPage, isPublicPage } from '../lib/inertia-page-access'

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

    let layout = resolved.layout
    if (layout === undefined) {
      if (name.startsWith('Home/') || name.startsWith('Public/')) {
        layout = PublicLayout as any
      } else if (!isPublicPage(name) && !isNoSidebarPage(name)) {
        layout = AuthenticatedLayout as any
      }
    }

    return {
      default: resolved.default,
      layout,
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
