<script lang="ts">
  import AuthenticatedLayout from '@/layouts/AuthenticatedLayout.svelte'
  import { isPublicPage } from '@/lib/inertia-page-access'

  let {
    pageName,
    component: Component,
    componentProps = {},
  }: {
    pageName: string
    component: any
    componentProps?: Record<string, unknown>
  } = $props()
</script>

{#if isPublicPage(pageName)}
  <div data-testid="page-test-content">
    <Component {...componentProps} />
  </div>
{:else}
  <AuthenticatedLayout>
    <div data-testid="page-test-content">
      <Component {...componentProps} />
    </div>
  </AuthenticatedLayout>
{/if}
