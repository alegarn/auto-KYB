<script lang="ts">
  
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import * as Card from "/components/ui/card";
  import { Button } from "/components/ui/button";
  import { router } from '@inertiajs/svelte';
  import { Input } from "/components/ui/input";
  import Modal from "/components/ui/modal.svelte";
  import * as Sheet from "/components/ui/sheet";
  import { Skeleton } from "/components/ui/skeleton";
  import { new_form_path, form_path, new_client_path, client_path, edit_client_path } from "@/routes";

  type Client = {
    id: string;
    name: string;
    status: "inactive" | "linked" | "active" | "validated";
    updated_at: string;
  };

  type Form = {
    id: string;
    name: string;
    status: "draft" | "submitted" | "approved" | "rejected";
    created_at: string;
    updated_at: string;
  };

  let { children, user, session_id, clients: initialClients, recent_forms: initialForms, meta } = $props();

  let clients = $derived<Client[]>(initialClients ?? []);
  let forms = $derived<Form[]>(initialForms ?? []);
  let loadingClients = $state(false);
  let loadingForms = $state(false);
  let search = $state("");
  let activeOnly = $state(false);
  let showModal = $state(false);
  let selectedToDelete = $state(null as any);

  
  const filteredClients = $derived.by(() =>
    clients.filter((client) => {
      const matchesSearch = [client.name, client.id]
        .join(" ")
        .toLowerCase()
        .includes(search.trim().toLowerCase());
      const matchesStatus = activeOnly ? client.status === "active" : true;
      return matchesSearch && matchesStatus;
    })
  );

   const totalPages = () => Math.max(1, Math.ceil(meta.total_count / meta.per_page));

   function pageRange(windowSize = 5) {
     const total = totalPages();
     const current = meta.page ?? 1;
     const half = Math.floor(windowSize / 2);
     let start = Math.max(1, current - half);
     let end = Math.min(total, start + windowSize - 1);
     if (end - start < windowSize - 1) start = Math.max(1, end - windowSize + 1);
     const range = [];
     for (let i = start; i <= end; i++) range.push(i);
     return range;
   }

  function goToPage(page: number) {
    if (page < 1 || page > totalPages() || page === meta.page) return;
    const params: Record<string, any> = { page };
    if (search && search.trim().length) params.q = search.trim();
    if (activeOnly) params.active_only = 1;

    router.get(window.location.pathname, params, {
      preserveState: true,
      preserveScroll: true,
      onStart: () => (loadingClients = true),
      onFinish: () => (loadingClients = false),
    });
  }

  function openDeleteModal(client: any) {
    selectedToDelete = client;
    showModal = true;
  }

  function confirmDelete() {
    if (!selectedToDelete) return;
    loadingClients = true;
    router.delete(client_path(selectedToDelete.id), {
      onStart: () => (loadingClients = true),
      onFinish: () => {
        loadingClients = false;
        selectedToDelete = null;
        showModal = false;
      },
      onError: () => (loadingClients = false),
    });
  }
  const totalClients = $derived.by(() => clients.length);
  const activeClients = $derived.by(() => clients.filter((client) => client.status === "active").length);
  const pendingClients = $derived.by(() => clients.filter((client) => client.status === "validated").length);
  const pendingForms = $derived.by(() => forms.filter((form) => form.status === "submitted").length);

  const recentForms = $derived.by(() => forms.slice(0, 5));

  const formStatusBadge = (status: Form["status"]) => {
    switch (status) {
      case "approved":
        return "bg-emerald-100 text-emerald-700";
      case "submitted":
        return "bg-blue-100 text-blue-700";
      case "rejected":
        return "bg-rose-100 text-rose-700";
      default:
        return "bg-amber-100 text-amber-700";
    }
  };
    
  const clientStatusBadge = (status: Client["status"]) => {
      switch (status) {
        case "validated":
          return "bg-emerald-100 text-emerald-700";
        case "active":
          return "bg-blue-100 text-blue-700";
        case "linked":
          return "bg-amber-100 text-amber-700";
        default:
          return "bg-slate-100 text-slate-600";
      }
    };
</script>

<Sidebar.Provider>
  <AppSidebar session_id={session_id} />
  <main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
    <Sidebar.Trigger class="mb-4" />
    {@render children?.()}

    <section class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
      <div>
        <p class="text-sm text-muted-foreground">Welcome back</p>
        <h1 class="text-2xl font-semibold text-foreground">Dashboard</h1>
          <!-- Pagination controls -->
          {#if meta && meta.total_count > meta.per_page}
            <div class="mt-3 flex items-center justify-between border-t pt-3">
              <div class="text-sm text-muted-foreground">Showing page {meta.page} of {totalPages()}</div>
              <nav class="flex items-center gap-2">
                <Button variant="ghost" size="sm" onclick={() => goToPage(meta.page - 1)} disabled={meta.page <= 1}>
                  Prev
                </Button>

                {#each pageRange(7) as p}
                  <button
                    class={`px-3 py-1 rounded ${p === meta.page ? 'bg-primary text-primary-foreground' : 'bg-background border'}`}
                    onclick={() => goToPage(p)}
                    aria-current={p === meta.page ? 'page' : undefined}
                  >
                    {p}
                  </button>
                {/each}

                <Button variant="ghost" size="sm" onclick={() => goToPage(meta.page + 1)} disabled={meta.page >= totalPages()}>
                  Next
                </Button>
              </nav>
            </div>
          {/if}
        <p class="text-sm text-muted-foreground">{user?.email}</p>
      </div>
      <div class="flex flex-col gap-2 sm:flex-row">
        <Button href={new_form_path()} variant="secondary">New Form</Button>
        <Button href={new_client_path()} variant="default">New Client</Button>

      </div>
    </section>

    <section class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <Card.Root>
        <Card.Header>
          <Card.Title>Total clients</Card.Title>
          <Card.Description>Across all statuses</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{totalClients}</p>
        </Card.Content>
      </Card.Root>
      <Card.Root>
        <Card.Header>
          <Card.Title>Active clients</Card.Title>
          <Card.Description>Currently onboarded</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{activeClients}</p>
        </Card.Content>
      </Card.Root>
      <Card.Root>
        <Card.Header>
          <Card.Title>Pending reviews</Card.Title>
          <Card.Description>Clients awaiting approval</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{pendingClients}</p>
        </Card.Content>
      </Card.Root>
      <Card.Root>
        <Card.Header>
          <Card.Title>Forms to review</Card.Title>
          <Card.Description>Submitted forms</Card.Description>
        </Card.Header>
        <Card.Content>
          <p class="text-3xl font-semibold">{pendingForms}</p>
        </Card.Content>
      </Card.Root>
    </section>

    <section class="mt-6 grid gap-6 lg:grid-cols-[2fr_1fr]">
      <Card.Root class="flex flex-col">
        <Card.Header class="gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <Card.Title>Clients</Card.Title>
            <Card.Description>Track your latest client activity.</Card.Description>
          </div>
          <div class="flex flex-col gap-2 sm:flex-row">
            <Input
              placeholder="Search clients"
              bind:value={search}
              class="sm:w-56"
            />
            <Button variant={activeOnly ? "default" : "secondary"} onclick={() => (activeOnly = !activeOnly)}>
              {activeOnly ? "Active only" : "All statuses"}
            </Button>
          </div>
        </Card.Header>
        <Card.Content class="flex-1 space-y-3">
          {#if loadingClients}
            {#each Array(4) as _}
              <div class="flex items-center justify-between gap-4">
                <div class="space-y-2">
                  <Skeleton class="h-4 w-40" />
                  <Skeleton class="h-3 w-24" />
                </div>
                <Skeleton class="h-8 w-20" />
              </div>
            {/each}
          {:else if filteredClients.length === 0}
            <div class="rounded-lg border border-dashed border-muted-foreground/30 p-6 text-center">
              <p class="text-sm font-medium">No clients found</p>
              <p class="text-sm text-muted-foreground">Try adjusting filters or create a new client.</p>
            </div>
          {:else}
            <div class="max-h-[420px] space-y-3 overflow-auto pr-2">
              {#each filteredClients as client}
                <div class="flex flex-col gap-3 rounded-lg border border-border bg-background p-4 sm:flex-row sm:items-center sm:justify-between">
                  <Button href={client_path(client.id)} variant="ghost" class="flex-1 no-underline p-0 text-left">
                    <div>
                      <p class="font-medium text-foreground">{client.name}</p>
                      <p class="text-sm text-muted-foreground">Updated {client.updated_at}</p>
                    </div>
                  </Button>
                  <div class="flex items-center gap-3">
                    <span class={`rounded-full px-2.5 py-1 text-xs font-semibold ${clientStatusBadge(client.status)}`}>
                      {client.status}
                    </span>
                    <Button variant="destructive" size="sm" onclick={() => openDeleteModal(client)}>Delete</Button>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </Card.Content>
      </Card.Root>

      <div class="space-y-6">
        <Card.Root>
          <Card.Header>
            <Card.Title>Quick actions</Card.Title>
            <Card.Description>Jump back into key workflows.</Card.Description>
          </Card.Header>
          <Card.Content class="space-y-3">
            <Button href={new_form_path()} class="w-full justify-between" variant="secondary">
              Start a new KYB form
              <span aria-hidden="true">→</span>
            </Button>
            <Button class="w-full justify-between" variant="secondary">
              Invite a teammate
              <span aria-hidden="true">→</span>
            </Button>
            <Button class="w-full justify-between" variant="secondary">
              Review pending submissions
              <span aria-hidden="true">→</span>
            </Button>
          </Card.Content>
        </Card.Root>

        <Card.Root>
          <Card.Header>
            <Card.Title>Recent forms</Card.Title>
            <Card.Description>Latest activity in your workspace.</Card.Description>
          </Card.Header>
          <Card.Content class="space-y-3">
            {#if loadingForms}
              {#each Array(3) as _}
                <div class="space-y-2">
                  <Skeleton class="h-4 w-32" />
                  <Skeleton class="h-3 w-20" />
                </div>
              {/each}
            {:else if forms.length === 0}
              <div class="rounded-lg border border-dashed border-muted-foreground/30 p-4 text-center">
                <p class="text-sm font-medium">No forms yet</p>
                <p class="text-sm text-muted-foreground">Create a form to start collecting data.</p>
              </div>
            {:else}
              {#each recentForms as form}
                <div class="flex items-center justify-between rounded-lg border border-border bg-background p-3">
                  <Button href={form_path(form.id)} class="flex-1 no-underline" variant="ghost">
                    <div>
                      <p class="text-sm font-medium text-foreground">{form.name}</p>
                      <p class="text-xs text-muted-foreground">Last update {form.updated_at}</p>
                    </div>
                  </Button>
                  <span class={`rounded-full px-2.5 py-1 text-xs font-semibold ${formStatusBadge(form.status)}`}>
                    {form.status}
                  </span>
                </div>
              {/each}
            {/if}
          </Card.Content>
        </Card.Root>
      </div>
    </section>
    
    <Modal bind:showModal={showModal} title="Delete client" description={selectedToDelete ? `Delete \"${selectedToDelete.name}\"?` : ''} onConfirm={confirmDelete} onClose={() => { selectedToDelete = null; showModal = false; }}>
      <p>Are you sure you want to delete "{selectedToDelete?.name}"?</p>
      {#if selectedToDelete?.status === 'active'}
        <p class="mt-2 text-sm text-amber-700">This client has started to fill a form — all in-progress data will be lost.</p>
      {:else}
        <p class="mt-2 text-sm text-muted-foreground">Deleting this client will remove their data and cannot be undone.</p>
      {/if}
    </Modal>
  </main>
</Sidebar.Provider>