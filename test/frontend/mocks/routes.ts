import { vi } from 'vitest'

export const dashboard_path = vi.fn(() => '/dashboard')
export const forms_path = vi.fn(() => '/forms')
export const new_form_path = vi.fn(() => '/forms/new')
export const edit_form_path = vi.fn((id: string) => `/forms/${id}/edit`)
export const form_path = vi.fn((id: string) => `/forms/${id}`)
export const settings_path = vi.fn(() => '/settings')
export const sessions_path = vi.fn(() => '/sessions')
export const new_session_path = vi.fn(() => '/sessions/new')
export const registrations_path = vi.fn(() => '/registrations')
export const new_registration_path = vi.fn(() => '/registrations/new')
export const destroy_session_path = vi.fn(() => '/sessions')
export const clients_path = vi.fn(() => '/clients')
export const client_form_invitation_delivery_path = vi.fn(
  (id: string | number) => `/client_forms/${id}/invitation_delivery`,
)

vi.mock('@/routes', () => ({
  dashboard_path,
  forms_path,
  new_form_path,
  edit_form_path,
  form_path,
  settings_path,
  sessions_path,
  new_session_path,
  registrations_path,
  new_registration_path,
  destroy_session_path,
  clients_path,
  client_form_invitation_delivery_path,
}))
