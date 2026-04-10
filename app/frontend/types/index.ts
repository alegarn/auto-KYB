import type { SharedAuth } from './shared-auth'

export type FlashData = {
  notice?: string
  alert?: string
}

export type SharedProps = {
  auth?: SharedAuth | null
  session_id?: string | null
}
