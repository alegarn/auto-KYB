import { flushSync, unmount } from 'svelte'
import { test, expect, vi, beforeEach } from 'vitest'
import { fireEvent, waitFor } from '@testing-library/svelte'

import Show from '../../../../app/frontend/pages/forms/show.svelte'
import { mountPage, renderPage } from '../helpers/renderPage'

const mount = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  mountPage({ pageName: 'forms/show', component, props: options.props ?? {} })

const render = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  renderPage({ pageName: 'forms/show', component, props: options.props ?? {} })

beforeEach(() => {
  vi.clearAllMocks()
  document.body.innerHTML = ''
})

test('Show form with no fields displays placeholder message', () => {
  const fakeForm = { id: '1', name: 'Empty Form', description: 'desc', form_fields: [] }
  const component: any = mount(Show as any, { target: document.body, props: { form: fakeForm } })

  expect(document.body.innerHTML).toContain('This form has no fields yet')

  unmount(component)
})

test('shows JSON and CSV results after submitting preview with fields', async () => {
  const fakeForm = {
    id: '1',
    name: 'Test Form',
    description: 'desc',
    form_fields: [
      { id: '1', label: 'First Name', field_type: 'text', position: 1, metadata: { export_key: 'first_name' } }
    ],
    structure: { settings: {} }
  }

  const { getByText, container } = render(Show, { props: { form: fakeForm } })

  // Fill the field
  const input = container.querySelector('input[name="field_1"]') as HTMLInputElement
  if (input) {
    input.value = 'John Doe'
    input.setAttribute('value', 'John Doe')
    await fireEvent.input(input, { target: { value: 'John Doe' } })
    await fireEvent.change(input, { target: { value: 'John Doe' } })
  }

  // Submit preview
  const form = container.querySelector('form')
  if (form) {
    await fireEvent.submit(form)
  }

  // Check JSON results
  await waitFor(() => {
    expect(getByText('Preview Results')).toBeInTheDocument()
  })
  
  const pre = container.querySelector('pre')
  expect(pre?.textContent).toContain('"first_name": "John Doe"')

  // Switch to CSV
  const csvBtn = getByText('CSV')
  await fireEvent.click(csvBtn)

  expect(pre?.textContent).toContain('label,value')
  expect(pre?.textContent).toContain('first_name,John Doe')
})
