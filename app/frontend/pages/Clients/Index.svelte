<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import { client_path, new_client_path, edit_client_path } from "@/routes";
  import { Input } from "/components/ui/input/index.js";
  import Button from '/components/ui/button/button.svelte';

  // read Inertia props via Svelte 5 $props
  let { children, user, session_id, clients = [], meta = { page: 1, per_page: 10, total_count: 0 } } = $props();

  // rune-first state
  let q = $state('');
  let page = $derived(meta.page);

  // derived rune for total pages
  const totalPages = $derived.by(() => Math.max(1, Math.ceil(meta.total_count / meta.per_page)));

  function goToPage(p: number) {
    router.get('/clients', { q: q, page: p }, { preserveState: true });
  }

  function search() {
    goToPage(1);
  }

  function deleteClient(id: string) {
    if (!confirm("Are you sure you want to delete this client?")) return;
    router.delete(client_path(id));
  }
</script>

<Sidebar.Provider>
  <AppSidebar session_id={session_id} />
  <main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8 flex-grow">
    <Sidebar.Trigger class="mb-4" />
    {@render children?.()}

    <section class="p-6 max-w-3xl mx-auto">
      <header class="mb-4">
        <h1 class="text-2xl font-semibold">Clients</h1>
        <p class="text-sm text-muted-foreground">{user?.email}</p>
      </header>

      <div class="mb-4 flex items-center gap-3">
        <form onsubmit={(e) => { e.preventDefault(); search(); }} class="flex flex-wrap gap-2 items-center">
          <label for="q" class="sr-only">Search clients</label>
          <Input id="q" name="q" bind:value={q} placeholder="Search by name or company" class="max-w-xs" />
          <Button type="submit">Search</Button>
          <Button type="button" variant="secondary" onclick={() => { q = ''; goToPage(1); }}>
            Clear search
          </Button>
        </form>
        <Button href={new_client_path()} class="btn">Add client</Button>
      </div>

      {#if clients.length === 0}
        <div class="rounded-lg border border-dashed p-6 text-center" role="status" aria-live="polite">
          <p class="text-sm font-medium">No clients found</p>
          <p class="text-sm text-muted-foreground">Create your first client.</p>
        </div>
      {:else}
        <ul class="space-y-3" role="list" aria-label="Client list">
          {#each clients as client}
            <li class="rounded-lg border p-4 flex items-center justify-between" role="listitem">
              <Button href={client_path(client['id'])} class="no-underline" aria-label={`View ${client['name']}`}>
                <div class="font-medium">{client['name']}</div>
                <div class="text-sm text-muted-foreground">{client['company_name']}</div>
              </Button>
              <div class="flex gap-2">
                <Button href={edit_client_path(client['id'])} class="btn btn-secondary">Edit</Button>
                <Button variant="destructive" size="sm" onclick={() => deleteClient(client['id'])}>Delete</Button>
              </div>
            </li>
          {/each}
        </ul>

        <!-- Pagination -->
        <nav class="mt-4 flex items-center justify-center" aria-label="Pagination">
          <ul class="inline-flex items-center space-x-2">
            {#each Array(totalPages) as _, i}
              <li>
                <button class={`px-3 py-1 rounded ${meta.page === i + 1 ? 'bg-foreground text-background' : 'bg-background border'}`} onclick={() => goToPage(i + 1)} aria-current={meta.page === i + 1 ? 'page' : undefined}>
                  {i + 1}
                </button>
              </li>
            {/each}
          </ul>
        </nav>
      {/if}
    </section>
  </main>
</Sidebar.Provider>
