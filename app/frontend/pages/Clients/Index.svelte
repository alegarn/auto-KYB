<script lang="ts">
  import { client_path, new_client_path, edit_client_path } from "@/routes";
  import Button from '/components/ui/button/button.svelte';

  let { user, clients = [] } = $props();
</script>

<main class="p-6">
  <header class="mb-4">
    <h1 class="text-2xl font-semibold">Clients</h1>
    <p class="text-sm text-muted-foreground">{user?.email}</p>
  </header>

  <div class="mb-4">
    <Button href={new_client_path()} class="btn">Add client</Button>
  </div>

  {#if clients.length === 0}
    <div class="rounded-lg border border-dashed p-6 text-center">
      <p class="text-sm font-medium">No clients found</p>
      <p class="text-sm text-muted-foreground">Create your first client.</p>
    </div>
  {:else}
    <ul class="space-y-3">
      {#each clients as client}
        <li class="rounded-lg border p-4 flex items-center justify-between">
          <Button href={client_path(client['id'])} class="no-underline">
            <div class="font-medium">{client['name']}</div>
            <div class="text-sm text-muted-foreground">{client['company_name']}</div>
          </Button>
          <div class="flex gap-2">
            <Button href={edit_client_path(client['id'])} class="btn btn-secondary">Edit</Button>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</main>
