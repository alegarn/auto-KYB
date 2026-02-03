<script lang="ts">
  import { onMount } from "svelte";
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import * as Card from "/components/ui/card";
  import { Button, buttonVariants } from "/components/ui/button";
  import { Input } from "/components/ui/input";
  import * as Sheet from "/components/ui/sheet";
  import { Skeleton } from "/components/ui/skeleton";
  import { new_form_path, form_path } from "@/routes";

  type Client = {
    id: string;
    name: string;
    status: "active" | "pending" | "inactive";
    updated_at: string;
  };

  type Form = {
    id: string;
    name: string;
    status: "draft" | "submitted" | "approved" | "rejected";
    created_at: string;
    updated_at: string;
  };

  let { children, user, session_id, recent_forms } = $props();

  const mockClients: Client[] = [
    { id: "CL-001", name: "Acme Logistics", status: "active", updated_at: "2026-01-27" },
    { id: "CL-002", name: "Northbridge Foods", status: "pending", updated_at: "2026-01-26" },
    { id: "CL-003", name: "Stellar Dynamics", status: "active", updated_at: "2026-01-24" },
    { id: "CL-004", name: "Juniper Health", status: "inactive", updated_at: "2026-01-22" },
    { id: "CL-005", name: "Redstone Labs", status: "active", updated_at: "2026-01-20" },
  ];

  let clients = $state<Client[]>([]);
  let forms = $derived<Form[]>(recent_forms ?? []);
  let loadingClients = $state(true);
  let loadingForms = $state(true);
  let search = $state("");
  let activeOnly = $state(false);

  onMount(() => {
    const timeout = setTimeout(() => {
      clients = mockClients;
      forms = recent_forms ?? [];
      loadingClients = false;
      loadingForms = false;
    }, 700);

    return () => clearTimeout(timeout);
  });

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

  const totalClients = $derived.by(() => clients.length);
  const activeClients = $derived.by(() => clients.filter((client) => client.status === "active").length);
  const pendingClients = $derived.by(() => clients.filter((client) => client.status === "pending").length);
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
      case "active":
        return "bg-emerald-100 text-emerald-700";
      case "pending":
        return "bg-blue-100 text-blue-700";
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
        <p class="text-sm text-muted-foreground">{user?.email}</p>
      </div>
      <div class="flex flex-col gap-2 sm:flex-row">
        <Button href={new_form_path()} variant="secondary">New Form</Button>
        <Sheet.Root>
          <Sheet.Trigger class={buttonVariants({ variant: "default" })}>
            New Client
          </Sheet.Trigger>
          <Sheet.Content side="right" class="w-full sm:max-w-lg">
            <Sheet.Header>
              <Sheet.Title>New client</Sheet.Title>
              <Sheet.Description>
                Add a client record quickly. You can complete details later.
              </Sheet.Description>
            </Sheet.Header>
            <div class="mt-6 space-y-4">
              <div class="space-y-2">
                <label class="text-sm font-medium" for="client-name">Client name</label>
                <Input id="client-name" placeholder="Acme Logistics" />
              </div>
              <div class="space-y-2">
                <label class="text-sm font-medium" for="client-id">Unique identifier</label>
                <Input id="client-id" placeholder="CL-006" />
              </div>
              <div class="space-y-2">
                <label class="text-sm font-medium" for="client-contact">Primary contact</label>
                <Input id="client-contact" placeholder="alex@acme.com" type="email" />
              </div>
            </div>
            <Sheet.Footer class="mt-6">
              <Sheet.Close class={buttonVariants({ variant: "secondary" })}>
                Cancel
              </Sheet.Close>
              <Sheet.Close class={buttonVariants({ variant: "default" })}>
                Save client
              </Sheet.Close>
            </Sheet.Footer>
          </Sheet.Content>
        </Sheet.Root>
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
            <Button variant={activeOnly ? "default" : "secondary"} on:click={() => (activeOnly = !activeOnly)}>
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
                  <div>
                    <p class="font-medium text-foreground">{client.name}</p>
                    <p class="text-sm text-muted-foreground">{client.id} · Updated {client.updated_at}</p>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class={`rounded-full px-2.5 py-1 text-xs font-semibold ${clientStatusBadge(client.status)}`}>
                      {client.status}
                    </span>
                    <Button variant="secondary" size="sm">View</Button>
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
  </main>
</Sidebar.Provider>