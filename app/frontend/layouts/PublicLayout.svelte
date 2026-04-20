<script lang="ts">
  import { page } from '@inertiajs/svelte';
  import { sign_in_path, sign_up_path, root_path, quickstart_path } from '@/routes';
  import { getPublicAuthCta, getSharedSessionId } from '@/lib/shared-auth';
  import Heroheader from '/components/ui/heroheader/heroheader.svelte';
  import Footer from '/components/ui/footer/footer.svelte';

  let { children } = $props();

  const publicAuthCta = $derived(getPublicAuthCta($page?.props as Record<string, unknown>));
  const sessionId = $derived(getSharedSessionId($page?.props as Record<string, unknown>));
</script>

<div class="min-h-screen flex flex-col">
  <Heroheader 
    sign_in_path={sign_in_path} 
    sign_up_path={sign_up_path} 
    root_path={root_path}
    quickstart_path={quickstart_path}
    publicAuthCta={publicAuthCta}
    sessionId={sessionId}
  />

  <main class="flex-1 overflow-hidden bg-background">
    {@render children?.()}
  </main>

  <Footer />
</div>
