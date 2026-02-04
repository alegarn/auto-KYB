<script lang="ts">
  import { client_path, new_client_path, edit_client_path } from "@/routes";
  import Button from '/components/ui/button/button.svelte';
  import { Form as InertiaForm } from '@inertiajs/svelte';

  let { user, clients = [], meta = { page: 1, per_page: 10, total_count: 0 } } = $props();
  let q = $state('');
  let page = $state(meta.page);

  const totalPages = $derived.by(() => Math.max(1, Math.ceil(meta.total_count / meta.per_page)));

  function goToPage(p: number) {
    Inertia.get('/clients', { q: q, page: p }, { preserveState: true });
  }

  function search() {
    goToPage(1);
  }

</script>

<main class="p-6">
  <header class="mb-4">
    <h1 class="text-2xl font-semibold">Clients</h1>
    <p class="text-sm text-muted-foreground">{user?.email}</p>
  </header>

  <div class="mb-4 flex items-center gap-3">
    <form onsubmit={(e) => { e.preventDefault(); search(); }} class="flex gap-2 items-center">
      <label for="q" class="sr-only">Search clients</label>
      <input id="q" name="q" bind:value={q} class="input" placeholder="Search by name or company" />
      <button type="submit" class="btn">Search</button>
      <button type="button" class="btn btn-secondary" on:click={() => { q = ''; goToPage(1); }}>Clear search</button>
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
          </div>
        </li>
      {/each}
    </ul>

    <!-- Pagination -->
    <nav class="mt-4 flex items-center justify-center" aria-label="Pagination">
      <ul class="inline-flex items-center space-x-2">
        {#each Array(totalPages) as _, i}
          <li>
            <button class={`px-3 py-1 rounded ${meta.page === i + 1 ? 'bg-foreground text-background' : 'bg-background border'}`} on:click={() => goToPage(i + 1)} aria-current={meta.page === i + 1 ? 'page' : undefined}>
              {i + 1}
            </button>
          </li>
        {/each}
      </ul>
    </nav>
  {/if}
</main>
