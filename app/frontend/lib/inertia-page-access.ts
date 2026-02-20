export const PUBLIC_PAGE_PREFIXES = [
  'ClientPortal/',
  'Home/',
  'sessions/',
  'registrations/',
  'inertia_example/',
] as const

export function isPublicPage(name: string): boolean {
  return PUBLIC_PAGE_PREFIXES.some((prefix) => name.startsWith(prefix))
}
