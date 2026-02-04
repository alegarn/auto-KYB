<script lang="ts">
  import { clients_path } from "@/routes";
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
      {#if client['address']}<p><strong>Address:</strong> {JSON.stringify(client['address'])}</p>{/if}
    </div>
  {:else}
    <p class="text-sm text-muted-foreground">Client not found.</p>
  {/if}

  <div class="mt-6">
    <Button href={clients_path()} class="btn">Back to clients</Button>
  </div>
</main>
