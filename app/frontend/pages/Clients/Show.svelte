<script lang="ts">
  import { clients_path, dashboard_path, edit_client_path, client_path, client_forms_path, export_responses_client_form_path, export_client_path, download_uploaded_file_path, uploaded_file_path } from "@/routes";
  import Button from '@/components/ui/button/button.svelte';
  import Modal from '@/components/ui/modal.svelte';
  import { Form as InertiaForm } from '@inertiajs/svelte';
  import { Label } from '/components/ui/label/index.js';
  import { router } from '@inertiajs/svelte';
  import { onMount } from 'svelte';
  import { fetchCountriesData } from '/lib/countries';
  import { computeFileExpiry, formatDuration } from '/lib/fileExpiry';
  import { FileText, Image, Download, Trash2 } from '@lucide/svelte';

  let { user, client = null, forms = [], client_form = null, uploaded_files = [], file_retention = null } = $props();
  let showConfirm = $state(false);
  let showFileDeleteConfirm = $state(false);
  let fileToDelete = $state<any>(null);

  let countries = $state<Array<{ name: string; code: string; flag: string }>>([]);
  let countriesByCode = $derived(() => (countries || []).reduce((h: Record<string, any>, c: any) => { h[String(c.code).toUpperCase()] = c; return h; }, {}));

  const displayCountry = $derived(() => {
    const code = client?.country;
    if (!code) return null;
    const lookup = countriesByCode();
    const found = lookup[String(code).toUpperCase()];
    return found || { name: String(code), code: String(code), flag: '' };
  });

  onMount(() => {
    fetchCountriesData().then((data) => { countries = data; }).catch((err) => console.error('countries load', err));
  });

  function openConfirm() {
    showConfirm = true;
  }

  function closeConfirm() {
    showConfirm = false;
  }

  function confirmDelete() {
    if (!client) return;
    router.delete(client_path(client['id']));
  }

  const clientStatusBadge = (status: string) => {
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

  const formStatusBadge = (status: string) => {
    switch (status) {
      case "validated":
        return "bg-emerald-100 text-emerald-700";
      case "filled":
        return "bg-blue-100 text-blue-700";
      case "draft":
        return "bg-amber-100 text-amber-700";
      default:
        return "bg-slate-100 text-slate-600";
    }
  };

  function formatFileSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  function formatFileDate(iso: string): string {
    return new Date(iso).toLocaleDateString(undefined, {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit'
    })
  }

  const filesWithExpiry = $derived((uploaded_files || []).map((f: any) => ({
    ...f,
    expiry: computeFileExpiry({ ...f, expires_at: f?.purge_scheduled_at })
  })));

  function openFileDeleteConfirm(file: any) {
    fileToDelete = file
    showFileDeleteConfirm = true
  }

  function closeFileDeleteConfirm() {
    fileToDelete = null
    showFileDeleteConfirm = false
  }

  function confirmFileDelete() {
    if (!fileToDelete) return
    router.delete(uploaded_file_path(fileToDelete.id))
    closeFileDeleteConfirm()
  }
</script>

<section class="p-6 w-full">
  <div class="w-full max-w-3xl mx-auto">
    <header class="mb-4">
      <h1 class="text-2xl font-semibold">Client details</h1>
      <p class="text-sm text-muted-foreground" aria-label="Signed in user">{user?.email}</p>
    </header>

    {#if client}
      <div class="space-y-2">
        <p><strong>Name:</strong> {client['name']}</p>
        <p><strong>Company:</strong> {client['company_name']}</p>
        <p><strong>Company ID:</strong> {client['company_id']}</p>
        <p><strong>Company's country:</strong>
          {#if displayCountry()?.name}
            <span>{displayCountry().flag} {displayCountry().name}</span>
          {:else}
            {client['country']}
          {/if}
        </p>
        <p><strong>Status:</strong>
          <span class={`ml-2 inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${clientStatusBadge(client['status'])}`}>
            {client['status']}
          </span>
        </p>
        {#if client['email']}<p><strong>Email:</strong> {client['email']}</p>{/if}
        {#if client['phone']}<p><strong>Phone:</strong> {client['phone']}</p>{/if}

        {#if client['address']}
          <div>
            <strong>Company's Address:</strong>
            {#if typeof client['address'] === 'string'}
              <div>{client['address']}</div>
            {:else}
              <div class="ml-2">
                {#if client['address']['street']}<div>{client['address']['street']}</div>{/if}
                {#if client['address']['city']}<div>{client['address']['city']}</div>{/if}
                {#if client['address']['postcode']}<div>{client['address']['postcode']}</div>{/if}
              </div>
            {/if}
          </div>
        {/if}
      </div>

      <div class="mt-6 border rounded p-4 bg-background">
        <h2 class="text-lg font-semibold mb-2">Client subspace</h2>

        {#if client_form}
          <p class="text-sm text-muted-foreground">Has a subspace</p>
          <div class="mt-2 text-sm">
            <div><strong>Form:</strong> {client_form.form?.name}</div>
            <div><strong>Status:</strong>
              <span class={`ml-2 inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${formStatusBadge(client_form.status)}`}>
                {client_form.status}
              </span>
            </div>
          </div>
        {:else}
          <InertiaForm method="post" action={client_forms_path()}>
            <input type="hidden" name="client_form[client_id]" value={client?.id} />
            <div class="space-y-2">
              <Label for="link-form" class="block text-sm font-medium">Link a form</Label>
              <select
                id="link-form"
                name="client_form[form_id]"
                class="w-full border rounded px-3 py-2 bg-background"
                required
                disabled={!forms || forms.length === 0}
              >
                <option value="">Select a form</option>
                {#each forms as form}
                  <option value={form.id}>{form.name}</option>
                {/each}
              </select>
              {#if !forms || forms.length === 0}
                <p class="text-sm text-muted-foreground">No forms available yet. Create a form first.</p>
              {/if}
            </div>

            <div class="mt-3">
              <Button type="submit" class="btn">Create subspace</Button>
            </div>
          </InertiaForm>
        {/if}
      </div>

      {#if uploaded_files && uploaded_files.length > 0}
        <div class="mt-6 border rounded p-4 bg-background">
          <h2 class="text-lg font-semibold mb-3">Uploaded files</h2>
          <div class="space-y-2">
            {#each filesWithExpiry as file (file.id)}
              <div class="flex items-center gap-3 rounded-md border border-border p-3">
                <div class="flex size-10 shrink-0 items-center justify-center rounded-md bg-muted">
                  {#if file.content_type?.startsWith('image/')}
                    <Image class="size-5 text-muted-foreground" aria-hidden="true" />
                  {:else}
                    <FileText class="size-5 text-muted-foreground" aria-hidden="true" />
                  {/if}
                </div>

                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-medium text-foreground">{file.filename}</p>
                  <p class="text-xs text-muted-foreground">
                    {formatFileSize(file.byte_size)} &middot; Uploaded at: {formatFileDate(file.uploaded_at)}
                    {#if file.expiry?.expiresAtIso}
                      &middot; Expires {formatFileDate(file.expiry.expiresAtIso)} ({formatDuration(file.expiry.remainingSeconds)})
                    {:else if file_retention?.purge_delay_seconds}
                      &middot; Purged {formatDuration(file_retention.purge_delay_seconds)} after first download
                    {:else}
                      &middot; Expiry starts after first download
                    {/if}
                  </p>
                </div>

                <div class="flex shrink-0 gap-1">
                  {#if !client_form || client_form.status === 'validated'}
                    <a
                      href={download_uploaded_file_path(file.id)}
                      class="rounded p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
                      aria-label={`Download ${file.filename}`}
                    >
                      <Download class="size-4" />
                    </a>
                  {:else}
                    <button
                      type="button"
                      class="rounded p-1.5 text-muted-foreground hover:bg-muted transition-colors opacity-50 cursor-not-allowed"
                      aria-label={`Download disabled until form is validated`}
                      title="Download disabled until form is validated"
                      disabled
                    >
                      <Download class="size-4" />
                    </button>
                  {/if}
                  <button
                    type="button"
                    class="rounded p-1.5 text-muted-foreground hover:bg-red-50 hover:text-red-600 transition-colors"
                    onclick={() => openFileDeleteConfirm(file)}
                    aria-label={`Delete ${file.filename}`}
                  >
                    <Trash2 class="size-4" />
                  </button>
                </div>
              </div>
            {/each}
          </div>
        </div>

        <Modal
          open={showFileDeleteConfirm}
          onClose={closeFileDeleteConfirm}
          onConfirm={confirmFileDelete}
        >
          {#snippet header()}
            <h2 class="text-lg font-semibold">Delete file</h2>
            <p class="text-sm text-muted-foreground">This will permanently remove this file. This action cannot be undone.</p>
          {/snippet}

          <p class="text-sm text-muted-foreground">
            Are you sure you want to delete {fileToDelete?.filename ?? 'this file'}?
          </p>
        </Modal>
      {/if}

      <div class="mt-6 flex gap-2">
        <Button href={edit_client_path(client['id'])} variant="secondary">Edit</Button>

        <Button onclick={openConfirm} class="btn-destructive" variant="destructive">Delete</Button>

        <a href={export_client_path(client['id'], { format: "json" })} target="_blank" rel="noopener" class="inline-flex items-center rounded-md px-4 py-2 text-sm font-semibold bg-background border shadow-xs" aria-label="Export client as JSON">Export client (JSON)</a>
        <a href={export_client_path(client['id'], { format: "csv" })} target="_blank" rel="noopener" class="inline-flex items-center rounded-md px-4 py-2 text-sm font-semibold bg-background border shadow-xs" aria-label="Export client as CSV">Export client (CSV)</a>
        {#if client_form && client_form.status === 'validated'}
          <a
            href={export_responses_client_form_path(client_form.id, { format: "csv" })}
            target="_blank"
            rel="noopener"
            class="inline-flex items-center rounded-md px-4 py-2 text-sm font-semibold bg-background border shadow-xs"
            aria-label="Export form responses as CSV"
          >
            Export Form Responses (CSV)
          </a>
        {/if}
        <Modal
          open={showConfirm}
          onClose={closeConfirm}
          onConfirm={confirmDelete}
        >
          {#snippet header()}
            <h2 class="text-lg font-semibold">Delete client</h2>
            <p class="text-sm text-muted-foreground">This will permanently delete the client. This action cannot be undone.</p>
          {/snippet}

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
  </div>
</section>
