import { render } from '@testing-library/svelte'
import { mount } from 'svelte'

import PageTestHost from './PageTestHost.svelte'

type RenderPageInput = {
  pageName: string
  component: any
  props?: Record<string, unknown>
}

export function renderPage({ pageName, component, props = {} }: RenderPageInput) {
  return render(PageTestHost, {
    props: {
      pageName,
      component,
      componentProps: props,
    },
  })
}

export function mountPage({ pageName, component, props = {} }: RenderPageInput) {
  return mount(PageTestHost as any, {
    target: document.body,
    props: {
      pageName,
      component,
      componentProps: props,
    },
  })
}
