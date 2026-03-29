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



  let { user, client = null, forms = [], client_form = null, uploaded_files = [], file_retention = null, crm_connections = [] } = $props();
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

  // CRM Export Dummy State
  let showCrmExportModal = $state(false);
  let crmExporting = $state(false);
  let crmExportSuccess = $state(false);
  let crmExportMessage = $state('');
  let selectedCrms = $state<string[]>(['hubspot']); // Default selected
  const availableCrms = $derived(
    (crm_connections || []).map((c: any) => ({
      id: c.provider,
      name: c.provider
    }))
  );


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

  function openCrmExport() {
    showCrmExportModal = true;
    crmExportSuccess = false;
    crmExportMessage = '';
  }

  function closeCrmExport() {
    showCrmExportModal = false;
  }

  function toggleCrmSelection(id: string) {
    if (selectedCrms.includes(id)) {
      selectedCrms = selectedCrms.filter(c => c !== id);
    } else {
      selectedCrms = [...selectedCrms, id];
    }
  }

  async function submitCrmExport() {
    if (selectedCrms.length === 0) return;
    
    crmExporting = true;
    crmExportMessage = '';
    try {
      const csrfToken = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '';
      const response = await fetch(`/clients/${client['id']}/export_to_crm`, {
        method: 'POST',
        headers: { 
          'X-CSRF-Token': csrfToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ crms: selectedCrms })
      });
      const body = await response.json().catch(() => ({}));

      if (response.ok) {
        crmExportMessage = body.message || 'Manual CRM export queued. Selected CRM transfers will run in the background and may take a moment to complete.';
        crmExportSuccess = true;
        setTimeout(() => {
          closeCrmExport();
        }, 2000);
      } else {
        alert(`Export failed: ${body.error || 'Unknown error'}`);
      }
    } catch (e: any) {
      alert(`Export failed: ${e.message}`);
    } finally {
      crmExporting = false;
    }
  }
</script>

<section class="p-6 w-full">
  <div class="w-full max-w-4xl mx-auto space-y-8">
    
    <!-- Header & Primary Actions -->
    <header class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-4 pb-4 border-b">
      <div>
        <h1 class="text-3xl font-semibold tracking-tight">Client details</h1>
        <p class="text-sm text-muted-foreground mt-1" aria-label="Signed in user">{user?.email}</p>
      </div>
      <div class="flex flex-wrap gap-2">
        {#if client}
          <Button href={edit_client_path(client['id'])} variant="secondary">Edit</Button>
          <Button onclick={openConfirm} variant="destructive">Delete</Button>
        {/if}
      </div>
    </header>

    {#if client}
      <!-- Client Information Grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-4">
        <div class="space-y-1">
          <p class="text-sm font-medium text-muted-foreground">Name</p>
          <p class="text-base font-medium">{client['name']}</p>
        </div>
        <div class="space-y-1">
          <p class="text-sm font-medium text-muted-foreground">Company</p>
          <div class="flex items-center gap-2">
            <p class="text-base">{client['company_name']}</p>
            <span class="text-xs text-muted-foreground px-2 py-0.5 bg-muted rounded-md">ID: {client['company_id']}</span>
          </div>
        </div>
        
        <div class="space-y-1">
          <p class="text-sm font-medium text-muted-foreground">Location</p>
          <p class="text-base flex items-center gap-2">
            {#if displayCountry()?.name}
              <span>{displayCountry().flag} {displayCountry().name}</span>
            {:else}
              {client['country']}
            {/if}
          </p>
        </div>
        
        <div class="space-y-1">
          <p class="text-sm font-medium text-muted-foreground">Status</p>
          <div>
            <span class={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${clientStatusBadge(client['status'])}`}>
              {client['status']}
            </span>
          </div>
        </div>

        {#if client['email']}
          <div class="space-y-1">
            <p class="text-sm font-medium text-muted-foreground">Email</p>
            <p class="text-base">{client['email']}</p>
          </div>
        {/if}
        
        {#if client['phone']}
          <div class="space-y-1">
            <p class="text-sm font-medium text-muted-foreground">Phone</p>
            <p class="text-base">{client['phone']}</p>
          </div>
        {/if}

        {#if client['address']}
          <div class="space-y-1 sm:col-span-2 mt-2">
            <p class="text-sm font-medium text-muted-foreground">Company's Address</p>
            <div class="text-base text-card-foreground/90 p-3 bg-muted/40 rounded-lg">
              {#if typeof client['address'] === 'string'}
                <div>{client['address']}</div>
              {:else}
                <div>
                  {#if client['address']['street']}<div>{client['address']['street']}</div>{/if}
                  {#if client['address']['city']}<div>{client['address']['city']}</div>{/if}
                  {#if client['address']['postcode']}<div>{client['address']['postcode']}</div>{/if}
                </div>
              {/if}
            </div>
          </div>
        {/if}
      </div>

      <!-- Client Subspace -->
      <div class="border rounded-xl p-5 bg-card text-card-foreground shadow-sm">
        <h2 class="text-lg font-semibold mb-1">Client subspace</h2>

        {#if client_form}
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mt-4">
            <div class="space-y-1">
              <p class="text-sm font-medium text-muted-foreground">Active Form</p>
              <p class="text-base font-medium">{client_form.form?.name}</p>
            </div>
            <div class="space-y-1 sm:text-right">
              <p class="text-sm font-medium text-muted-foreground">Status</p>
              <div>
                <span class={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${formStatusBadge(client_form.status)}`}>
                  {client_form.status}
                </span>
              </div>
            </div>
          </div>
        {:else}
          <p class="text-sm text-muted-foreground mb-4">No active subspace yet. Link a form to create one.</p>
          <InertiaForm method="post" action={client_forms_path()} class="max-w-md">
            <input type="hidden" name="client_form[client_id]" value={client?.id} />
            <div class="space-y-3">
              <div class="space-y-1.5">
                <Label for="link-form" class="text-sm font-medium">Link a form</Label>
                <select
                  id="link-form"
                  name="client_form[form_id]"
                  class="flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                  required
                  disabled={!forms || forms.length === 0}
                >
                  <option value="">Select a form</option>
                  {#each forms as form}
                    <option value={form.id}>{form.name}</option>
                  {/each}
                </select>
                {#if !forms || forms.length === 0}
                  <p class="text-xs text-muted-foreground">No forms available yet. Create a form first.</p>
                {/if}
              </div>
              <Button type="submit" class="w-full sm:w-auto">Create subspace</Button>
            </div>
          </InertiaForm>
        {/if}
      </div>

      {#if uploaded_files && uploaded_files.length > 0}
        <div class="border rounded-xl p-5 bg-card text-card-foreground shadow-sm">
          <h2 class="text-lg font-semibold mb-4">Uploaded files</h2>
          <div class="space-y-3">
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

                <div class="flex shrink-0 gap-2">
                  {#if !client_form || client_form.status === 'validated'}
                    <a
                      href={download_uploaded_file_path(file.id)}
                      class="rounded-md p-2 text-muted-foreground hover:bg-secondary hover:text-secondary-foreground transition-colors"
                      aria-label={`Download ${file.filename}`}
                    >
                      <Download class="size-4.5" />
                    </a>
                  {:else}
                    <button
                      type="button"
                      class="rounded-md p-2 text-muted-foreground transition-colors opacity-50 cursor-not-allowed"
                      aria-label={`Download disabled until form is validated`}
                      title="Download disabled until form is validated"
                      disabled
                    >
                      <Download class="size-4.5" />
                    </button>
                  {/if}
                  <button
                    type="button"
                    class="rounded-md p-2 text-muted-foreground hover:bg-destructive/10 hover:text-destructive transition-colors"
                    onclick={() => openFileDeleteConfirm(file)}
                    aria-label={`Delete ${file.filename}`}
                  >
                    <Trash2 class="size-4.5" />
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

      <!-- Data Exports & Actions -->
      <div class="pt-8 mt-4 border-t">
        <h2 class="text-xl font-semibold mb-6 flex items-center gap-2">
          <Download class="size-5 text-muted-foreground" />
          Data inventory & exports
        </h2>
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Client Profile Exports -->
          <div class="p-4 rounded-xl border bg-muted/30">
            <h3 class="text-sm font-semibold uppercase tracking-wider text-muted-foreground mb-4">Client profile</h3>
            <div class="flex flex-wrap gap-2">
              <a href={export_client_path(client['id'], { format: "json" })} target="_blank" rel="noopener" class="inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-medium bg-background border shadow-sm hover:bg-muted transition-colors" aria-label="Export client as JSON">
                <FileText class="size-4" /> JSON
              </a>
              <a href={export_client_path(client['id'], { format: "csv" })} target="_blank" rel="noopener" class="inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-medium bg-background border shadow-sm hover:bg-muted transition-colors" aria-label="Export client as CSV">
                <FileText class="size-4" /> CSV
              </a>
            </div>
          </div>

          <!-- Form Response Exports -->
          {#if client_form && client_form.status === 'validated'}
            <div class="p-4 rounded-xl border bg-muted/30">
              <h3 class="text-sm font-semibold uppercase tracking-wider text-muted-foreground mb-4">Form responses</h3>
              <div class="flex flex-wrap gap-2">
                <a
                  href={export_responses_client_form_path(client_form.id, { format: "csv" })}
                  target="_blank"
                  rel="noopener"
                  class="inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-medium bg-background border shadow-sm hover:bg-muted transition-colors"
                  aria-label="Export form responses as CSV"
                >
                  <Download class="size-4" /> Download CSV
                </a>
                {#if user?.can_use_crm}
                <Button variant="outline" onclick={openCrmExport} class="gap-2 shadow-sm">
                  <span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span>
                  Export to CRM
                </Button>
                {/if}
              </div>
            </div>
          {/if}
        </div>
      </div>
        
        <Modal
          open={showConfirm}
          onClose={closeConfirm}
          onConfirm={confirmDelete}
        >
          {#snippet header()}
            <h2 class="text-lg font-semibold border-none">Delete client</h2>
            <p class="text-sm text-muted-foreground">This will permanently delete the client. This action cannot be undone.</p>
          {/snippet}

          <p class="text-sm text-muted-foreground">Are you sure you want to delete this client?</p>
        </Modal>
    {:else}
      <div class="flex flex-col items-center justify-center p-12 text-center border rounded-xl bg-card">
        <p class="text-lg font-medium text-muted-foreground">Client not found.</p>
      </div>
    {/if}
    <!-- Footer Navigation -->
    <div class="flex gap-3 pt-6">
      <Button href={clients_path()} variant="outline">Back to clients</Button>
      <Button href={dashboard_path()} variant="ghost">Back to dashboard</Button>
    </div>
  </div>

  <Modal
    open={showCrmExportModal}
    onClose={closeCrmExport}
    onConfirm={submitCrmExport}
    confirmText={crmExporting ? "Exporting..." : "Export"}
    confirmDisabled={crmExporting || selectedCrms.length === 0}
  >
    {#snippet header()}
      <h2 class="text-lg font-semibold">Export Form Answers to CRM</h2>
      <p class="text-sm text-muted-foreground">Select the CRMs you want to export this client's data to.</p>
    {/snippet}

    <div class="space-y-4 py-2">
      {#if crmExportSuccess}
        <div class="p-3 bg-emerald-50 text-emerald-700 rounded-md text-sm font-medium">
          {crmExportMessage}
        </div>
      {:else}
        <div class="space-y-2">
          {#each availableCrms as crm}
            <label class="flex items-center gap-3 p-3 border rounded-md cursor-pointer hover:bg-muted/50 transition-colors">
              <input 
                type="checkbox" 
                class="rounded border-gray-300 text-primary focus:ring-primary"
                checked={selectedCrms.includes(crm.id)}
                onchange={() => toggleCrmSelection(crm.id)}
                disabled={crmExporting}
              />
              <span class="text-sm font-medium">{crm.name}</span>
            </label>
          {/each}
        </div>
        {#if selectedCrms.length === 0}
          <p class="text-sm text-destructive">Please select at least one CRM.</p>
        {/if}
      {/if}
    </div>
  </Modal>
</section>
