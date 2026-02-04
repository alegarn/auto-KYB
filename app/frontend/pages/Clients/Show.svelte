<script lang="ts">
  import { clients_path, dashboard_path, edit_client_path, client_path } from "@/routes";
  import Button from '@/components/ui/button/button.svelte';
  import Modal from '@/components/ui/modal.svelte';
  import { Inertia } from '@inertiajs/inertia';

  let { user, client = null } = $props();
  let showConfirm = $state(false);

  function openConfirm() {
    showConfirm = true;
  }

  function closeConfirm() {
    showConfirm = false;
  }

  function confirmDelete() {
    if (!client) return;
    Inertia.delete(client_path(client['id']));
  }
</script>

<main class="p-6">
  <header class="mb-4">
    <h1 class="text-2xl font-semibold">Client details</h1>
    <p class="text-sm text-muted-foreground" aria-label="Signed in user">{user?.email}</p>
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

      <Button on:click={openConfirm} class="btn-destructive" variant="destructive">Delete</Button>

      <!-- Export buttons for GDPR: JSON and CSV exports open in a new tab for download / machine consumption -->
      <Button href={`/clients/${client['id']}/export.json`} target="_blank" rel="noopener" variant="outline" aria-label="Export client as JSON">Export (JSON)</Button>
      <Button href={`/clients/${client['id']}/export.csv`} target="_blank" rel="noopener" variant="outline" aria-label="Export client as CSV">Export (CSV)</Button>

      <Modal
        title="Delete client"
        description="This will permanently delete the client. This action cannot be undone."
        open={showConfirm}
        onClose={closeConfirm}
        onConfirm={confirmDelete}
      >
        <p class="text-sm text-muted-foreground">Are you sure you want to delete this client?</p>
      </Modal>
    </div>
  {:else}
    <p class="text-sm text-muted-foreground">Client not found.</p>
  {/if}

  <div class="mt-6 flex gap-2">
    <Button href={clients_path()} class="btn">Back to clients</Button>
    <Button href={dashboard_path()} class="btn" variant="ghost">Back to dashboard</Button>
  </div>
</main>
