export const PUBLIC_PAGE_PREFIXES = [
  'ClientPortal/',
  'Home/',
  'sessions/',
  'registrations/',
  'inertia_example/',
] as const

export const NO_SIDEBAR_PAGE_PREFIXES = [
  'Auth/',
] as const

export function isPublicPage(name: string): boolean {
  return PUBLIC_PAGE_PREFIXES.some((prefix) => name.startsWith(prefix))
}

export function isNoSidebarPage(name: string): boolean {
  return NO_SIDEBAR_PAGE_PREFIXES.some((prefix) => name.startsWith(prefix))
}
