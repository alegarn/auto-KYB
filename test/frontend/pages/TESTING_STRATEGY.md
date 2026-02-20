# Frontend page test strategy

## Goal

Keep page specs aligned with Inertia runtime behavior, including the authenticated layout wrapper.

## Rules

- Use `renderPage` / `mountPage` from `test/frontend/pages/helpers/renderPage.ts` for page specs.
- Pass the real Inertia page path name (for example `forms/index`, `Dashboard/Dashboard`, `Home/Index`).
- Let the helper decide whether the page is public or authenticated.
- Do not mock layout internals unless a test explicitly targets layout behavior.

## Shared source of truth

- Public-page detection is shared between runtime and tests via `app/frontend/lib/inertia-page-access.ts`.
- `app/frontend/entrypoints/inertia.ts` and page test helpers both use `isPublicPage`.

## Examples

```ts
renderPage({
  pageName: 'Clients/New',
  component: NewClient,
  props: { user: { email: 'test@example.com' } },
})

mountPage({
  pageName: 'Dashboard/Dashboard',
  component: Dashboard,
  props: { ...mockPageProps.props },
})
```
