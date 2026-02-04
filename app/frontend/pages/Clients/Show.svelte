<script lang="ts">
  import { clients_path, dashboard_path, edit_client_path, client_path } from "@/routes";
  import Button from '@/components/ui/button/button.svelte';

  let { user, client = null } = $props();
</script>

<main class="p-6">
  <header class="mb-4">
    <h1 class="text-2xl font-semibold">Client details</h1>
    <p class="text-sm text-muted-foreground">{user?.email}</p>
  </header>

  {#if client}
    <div class="space-y-2">
      <p><strong>Name:</strong> {client['name']}</p>
      <p><strong>Company:</strong> {client['company_name']}</p>
      {#if client['email']}<p><strong>Email:</strong> {client['email']}</p>{/if}
      {#if client['phone']}<p><strong>Phone:</strong> {client['phone']}</p>{/if}

      {#if client['address']}
        <div>
          <strong>Address:</strong>
          {#if typeof client['address'] === 'string'}
            <div>{client['address']}</div>
          {:else}
            <div class="ml-2">
              {#if client['address']['street']}<div>{client['address']['street']}</div>{/if}
              {#if client['address']['city']}<div>{client['address']['city']}</div>{/if}
              {#if client['address']['postcode']}<div>{client['address']['postcode']}</div>{/if}
              {#if client['address']['country']}<div>{client['address']['country']}</div>{/if}
            </div>
          {/if}
        </div>
      {/if}
    </div>

    <div class="mt-6 flex gap-2">
      <Button href={edit_client_path(client['id'])} variant="secondary">Edit</Button>

      <form method="post" action={client_path(client['id'])} on:submit|preventDefault={() => { /* handled by server/inertia */ }}>
        <input type="hidden" name="_method" value="delete" />
        <Button class="btn-destructive" variant="destructive">Delete</Button>
      </form>
    </div>
  {:else}
    <p class="text-sm text-muted-foreground">Client not found.</p>
  {/if}

  <div class="mt-6 flex gap-2">
    <Button href={clients_path()} class="btn">Back to clients</Button>
    <Button href={dashboard_path()} class="btn" variant="ghost">Back to dashboard</Button>
  </div>
</main>
