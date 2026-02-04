<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import { client_path, new_client_path, edit_client_path } from "@/routes";
  import * as Card from "/components/ui/card";
  import { Input } from "/components/ui/input/index.js";
  import Button from '/components/ui/button/button.svelte';

  // read Inertia props via Svelte 5 $props
  let { children, user, session_id, clients = [], meta = { page: 1, per_page: 10, total_count: 0 } } = $props();

  // rune-first state
  let q = $state('');
  let page = $derived(meta.page);

  // derived rune for total pages
  const totalPages = $derived.by(() => Math.max(1, Math.ceil(meta.total_count / meta.per_page)));
  const totalClients = $derived.by(() => clients.length);
  const companiesCount = $derived.by(() =>
    new Set(clients.map((client) => (client?.company_name || "").trim()).filter(Boolean)).size
  );
  const contactsCount = $derived.by(() =>
    clients.filter((client) => (client?.email || "").trim().length > 0).length
  );

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

    <section class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
      <div>
        <p class="text-sm text-muted-foreground">Workspace</p>
        <h1 class="text-2xl font-semibold text-foreground">My Clients</h1>
        <p class="text-sm text-muted-foreground">{user?.email}</p>
      </div>
      <div class="flex flex-col gap-2 sm:flex-row">
        <Button href={new_client_path()} variant="default">Add client</Button>
      </div>
    </section>

    <section class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <Card.Root>
        <Card.Header>
          <Card.Title>Total clients</Card.Title>
          <Card.Description>Across all companies</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{totalClients}</p>
        </Card.Content>
      </Card.Root>
      <Card.Root>
        <Card.Header>
          <Card.Title>Companies</Card.Title>
          <Card.Description>Unique company names</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{companiesCount}</p>
        </Card.Content>
      </Card.Root>
      <Card.Root>
        <Card.Header>
          <Card.Title>Contacts</Card.Title>
          <Card.Description>Clients with email</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{contactsCount}</p>
        </Card.Content>
      </Card.Root>
      <Card.Root>
        <Card.Header>
          <Card.Title>Pages</Card.Title>
          <Card.Description>Pagination overview</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{totalPages}</p>
        </Card.Content>
      </Card.Root>
    </section>

    <section class="mt-6">
      <Card.Root>
        <Card.Header class="gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <Card.Title>Client list</Card.Title>
            <Card.Description>Manage and track client details.</Card.Description>
          </div>
          <div class="flex flex-col gap-2 sm:flex-row">
            <form onsubmit={(e) => { e.preventDefault(); search(); }} class="flex items-center gap-2">
              <label for="q" class="sr-only">Search clients</label>
              <Input id="q" name="q" bind:value={q} placeholder="Search by name or company" class="sm:w-56" />
              <div class="flex items-center gap-2">
                <Button type="submit" size="sm">Search</Button>
                <Button type="button" size="sm" variant="secondary" onclick={() => { q = ''; goToPage(1); }}>
                  Clear
                </Button>
              </div>
            </form>
          </div>
        </Card.Header>
        <Card.Content class="space-y-3">
          {#if clients.length === 0}
            <div class="rounded-lg border border-dashed border-muted-foreground/30 p-6 text-center" role="status" aria-live="polite">
              <p class="text-sm font-medium">No clients found</p>
              <p class="text-sm text-muted-foreground">Create your first client.</p>
            </div>
          {:else}
            <div class="max-h-[520px] space-y-3 overflow-auto pr-2">
              {#each clients as client}
                <div class="flex flex-col gap-3 rounded-lg border border-border bg-background p-4 sm:flex-row sm:items-center sm:justify-between">
                  <Button href={client_path(client['id'])} variant="ghost" class="flex-1 no-underline p-0 text-left" aria-label={`View ${client['name']}`}>
                    <div>
                      <div class="font-medium">{client['name']}</div>
                      <div class="text-sm text-muted-foreground">{client['company_name']}</div>
                    </div>
                  </Button>
                  <div class="flex items-center gap-3">
                    <Button href={edit_client_path(client['id'])} variant="secondary" size="sm">Edit</Button>
                    <Button variant="destructive" size="sm" onclick={() => deleteClient(client['id'])}>Delete</Button>
                  </div>
                </div>
              {/each}
            </div>

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
        </Card.Content>
      </Card.Root>
    </section>
  </main>
</Sidebar.Provider>
