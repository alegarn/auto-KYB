<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import { page } from "@inertiajs/svelte";

  let { children } = $props();

  const sessionId = $derived(($page?.props as Record<string, unknown>)?.session_id as string);
</script>

<Sidebar.Provider>
  <AppSidebar session_id={sessionId} />
  <main class="min-h-screen w-full bg-muted/40 px-4 py-6 md:px-8">
    <Sidebar.Trigger class="mb-4" />
    {@render children?.()}
  </main>
</Sidebar.Provider>
