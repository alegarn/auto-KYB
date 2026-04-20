import type { SharedAuth } from './shared-auth'

export type FlashData = {
  notice?: string
  alert?: string
}

export type SharedPublicAuthCta = {
  label: string
  href: string
}

export type SharedProps = {
  auth?: SharedAuth | null
  session_id?: string | null
  public_auth_cta?: SharedPublicAuthCta | null
}
