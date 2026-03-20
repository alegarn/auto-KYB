<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import Button from '/components/ui/button/button.svelte';
  import * as Table from '/components/ui/table';
  import * as Sheet from '/components/ui/sheet';
  import { CheckCircle2, Clock3, LoaderCircle, RotateCcw, XCircle } from '@lucide/svelte';

  type TransferRow = {
    id: string;
    created_at?: string | null;
    provider: string;
    status: string;
    trigger: string;
    attempts_count: number;
    retryable: boolean;
    error_message?: string | null;
    client?: {
      id?: string;
      name?: string | null;
      company_name?: string | null;
    } | null;
  };

  type Filters = {
    status?: string | null;
    provider?: string | null;
    trigger?: string | null;
  };

  type FilterOptions = {
    statuses: string[];
    providers: string[];
    triggers: string[];
  };

  type Meta = {
    page: number;
    per_page: number;
    total_count: number;
  };

  let {
    transfers = [],
    filters = {},
    filter_options = { statuses: [], providers: [], triggers: [] },
    meta = { page: 1, per_page: 10, total_count: 0 },
    retention_days = 3
  }: {
    transfers?: TransferRow[];
    filters?: Filters;
    filter_options?: FilterOptions;
    meta?: Meta;
    retention_days?: number;
  } = $props();

  let status = $state('');
  let provider = $state('');
  let trigger = $state('');
  let retryingTransferId = $state<string | null>(null);
  let selectedTransfer = $state<TransferRow | null>(null);
  let sheetOpen = $state(false);

  function openDetail(transfer: TransferRow) {
    selectedTransfer = transfer;
    sheetOpen = true;
  }

  $effect(() => {
    status = filters.status ?? '';
    provider = filters.provider ?? '';
    trigger = filters.trigger ?? '';
  });

  const totalPages = $derived.by(() => Math.max(1, Math.ceil(meta.total_count / meta.per_page)));
  const hasActiveFilters = $derived(Boolean(status || provider || trigger));

  function formatDate(iso: string) {
    return new Date(iso).toLocaleString(undefined, {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  }

  function buildQuery(page = 1) {
    const params: Record<string, string | number> = { page };

    if (status) params.status = status;
    if (provider) params.provider = provider;
    if (trigger) params.trigger = trigger;

    return params;
  }

  function applyFilters() {
    router.get('/crm_transfers', buildQuery(1), {
      preserveState: true,
      preserveScroll: true,
      replace: true,
    });
  }

  function clearFilters() {
    status = '';
    provider = '';
    trigger = '';
    applyFilters();
  }

  function goToPage(pageNumber: number) {
    router.get('/crm_transfers', buildQuery(pageNumber), {
      preserveState: true,
      preserveScroll: true,
      replace: true,
    });
  }

  function retryTransfer(transferId: string) {
    retryingTransferId = transferId;

    router.post(
      `/crm_transfers/${transferId}/retry`,
      {
        page: meta.page,
        status,
        provider,
        trigger,
      },
      {
        preserveScroll: true,
        onFinish: () => {
          retryingTransferId = null;
        },
      }
    );
  }

  function providerLabel(value: string) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }

  function triggerLabel(value: string) {
    return value
      .split('_')
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ');
  }

  function statusLabel(value: string) {
    switch (value) {
      case 'processing':
        return 'Processing';
      case 'success':
        return 'Success';
      case 'failed':
        return 'Failed';
      default:
        return 'Queued';
    }
  }

  function detailText(transfer: TransferRow) {
    if (transfer.error_message) return transfer.error_message;
    if (transfer.status === 'success') return 'Transfer completed successfully';
    if (transfer.status === 'processing') return 'Transfer is currently running';
    return 'Transfer is queued and waiting to run';
  }
</script>

<section class="p-6 w-full">
  <div class="w-full max-w-6xl mx-auto">
    <header class="mb-6 flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
      <div>
        <h1 class="text-2xl font-semibold">CRM Transfer History</h1>
        <p class="text-sm text-muted-foreground">
          Operational transfer history for the last {retention_days} days. Older records are removed automatically.
        </p>
      </div>
      <Button href="/dashboard" variant="outline">Back to dashboard</Button>
    </header>

    <div class="mb-6 rounded-md border bg-background p-4">
      <div class="grid grid-cols-1 gap-4 md:grid-cols-4">
        <label class="grid gap-2 text-sm font-medium" for="status-filter">
          Status
          <select id="status-filter" bind:value={status} class="h-10 rounded-md border bg-background px-3 text-sm">
            <option value="">All statuses</option>
            {#each filter_options.statuses as option}
              <option value={option}>{statusLabel(option)}</option>
            {/each}
          </select>
        </label>

        <label class="grid gap-2 text-sm font-medium" for="provider-filter">
          Provider
          <select id="provider-filter" bind:value={provider} class="h-10 rounded-md border bg-background px-3 text-sm">
            <option value="">All providers</option>
            {#each filter_options.providers as option}
              <option value={option}>{providerLabel(option)}</option>
            {/each}
          </select>
        </label>

        <label class="grid gap-2 text-sm font-medium" for="trigger-filter">
          Trigger
          <select id="trigger-filter" bind:value={trigger} class="h-10 rounded-md border bg-background px-3 text-sm">
            <option value="">All triggers</option>
            {#each filter_options.triggers as option}
              <option value={option}>{triggerLabel(option)}</option>
            {/each}
          </select>
        </label>

        <div class="flex items-end gap-2">
          <Button type="button" onclick={applyFilters}>Apply filters</Button>
          <Button type="button" variant="secondary" onclick={clearFilters}>Clear</Button>
        </div>
      </div>
    </div>

    <div class="rounded-md border bg-background overflow-hidden w-full">
      <div class="overflow-x-auto">
        {#if transfers.length === 0}
          <div class="p-10 text-center" role="status" aria-live="polite">
            {#if hasActiveFilters}
              <p class="text-sm font-medium">No transfers match the current filters</p>
              <p class="mt-1 text-sm text-muted-foreground">Adjust the filters or clear them to see the full 3-day operational history.</p>
            {:else}
              <p class="text-sm font-medium">No CRM transfers in the last {retention_days} days</p>
              <p class="mt-1 text-sm text-muted-foreground">Manual exports, portal submit syncs, and other transfer activity will appear here.</p>
            {/if}
          </div>
        {:else}
          <Table.Root class="w-full table-fixed">
            <colgroup>
              <col class="w-[155px]" />
              <col class="w-[130px]" />
              <col class="w-[90px]" />
              <col class="w-[130px] hidden md:table-column" />
              <col class="w-[105px]" />
              <col class="w-[75px] hidden md:table-column" />
              <col />
              <col class="w-[85px]" />
            </colgroup>
            <Table.Header>
              <Table.Row>
                <Table.Head>Date</Table.Head>
                <Table.Head>Client</Table.Head>
                <Table.Head>Provider</Table.Head>
                <Table.Head class="hidden md:table-cell">Trigger</Table.Head>
                <Table.Head>Status</Table.Head>
                <Table.Head class="hidden md:table-cell">Attempts</Table.Head>
                <Table.Head>Details</Table.Head>
                <Table.Head class="text-right">Actions</Table.Head>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {#each transfers as transfer}
                <Table.Row
                  class="cursor-pointer hover:bg-muted/50"
                  onclick={() => openDetail(transfer)}
                >
                  <Table.Cell class="font-medium">
                    <span class="block truncate" title={transfer.created_at ? formatDate(transfer.created_at) : '-'}>
                      {transfer.created_at ? formatDate(transfer.created_at) : '-'}
                    </span>
                  </Table.Cell>
                  <Table.Cell>
                    <span class="block truncate" title={transfer.client?.company_name || transfer.client?.name || '-'}>
                      {transfer.client?.company_name || transfer.client?.name || '-'}
                    </span>
                  </Table.Cell>
                  <Table.Cell>
                    <span class="block truncate" title={providerLabel(transfer.provider)}>
                      {providerLabel(transfer.provider)}
                    </span>
                  </Table.Cell>
                  <Table.Cell class="hidden md:table-cell">
                    <span class="block truncate" title={triggerLabel(transfer.trigger)}>
                      {triggerLabel(transfer.trigger)}
                    </span>
                  </Table.Cell>
                  <Table.Cell>
                    <div class="flex items-center gap-1.5">
                      {#if transfer.status === 'success'}
                        <CheckCircle2 class="size-4 shrink-0 text-emerald-500" />
                        <span class="text-sm font-medium text-emerald-700 truncate">Success</span>
                      {:else if transfer.status === 'failed'}
                        <XCircle class="size-4 shrink-0 text-destructive" />
                        <span class="text-sm font-medium text-destructive truncate">Failed</span>
                      {:else if transfer.status === 'processing'}
                        <LoaderCircle class="size-4 shrink-0 animate-spin text-blue-600" />
                        <span class="text-sm font-medium text-blue-700 truncate">Processing</span>
                      {:else}
                        <Clock3 class="size-4 shrink-0 text-amber-500" />
                        <span class="text-sm font-medium text-amber-700 truncate">Queued</span>
                      {/if}
                    </div>
                  </Table.Cell>
                  <Table.Cell class="hidden md:table-cell">{transfer.attempts_count}</Table.Cell>
                  <Table.Cell class="text-sm text-muted-foreground">
                    <span class="block truncate" title={detailText(transfer)}>
                      {detailText(transfer)}
                    </span>
                  </Table.Cell>
                  <Table.Cell class="text-right" onclick={(e) => e.stopPropagation()}>
                    {#if transfer.status === 'failed' && transfer.retryable}
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        onclick={() => retryTransfer(transfer.id)}
                        disabled={retryingTransferId === transfer.id}
                      >
                        <RotateCcw class="mr-1 size-4" />
                        {retryingTransferId === transfer.id ? 'Retrying...' : 'Retry'}
                      </Button>
                    {:else}
                      <span class="text-sm text-muted-foreground">-</span>
                    {/if}
                  </Table.Cell>
                </Table.Row>
              {/each}
            </Table.Body>
          </Table.Root>
        {/if}
      </div>
    </div>

    {#if transfers.length > 0 && totalPages > 1}
      <nav class="mt-4 flex items-center justify-center" aria-label="Pagination">
        <ul class="inline-flex items-center space-x-2">
          {#each Array(totalPages) as _, index}
            <li>
              <button
                class={`px-3 py-1 rounded ${meta.page === index + 1 ? 'bg-foreground text-background' : 'bg-background border'}`}
                onclick={() => goToPage(index + 1)}
                aria-current={meta.page === index + 1 ? 'page' : undefined}
              >
                {index + 1}
              </button>
            </li>
          {/each}
        </ul>
      </nav>
    {/if}
  </div>
</section>

<Sheet.Root bind:open={sheetOpen} onOpenChange={(open) => { if (!open) selectedTransfer = null; }}>
  <Sheet.Content side="right" class="w-full sm:max-w-md overflow-y-auto">
    {#if selectedTransfer}
      <Sheet.Header class="mb-4">
        <Sheet.Title>Transfer Details</Sheet.Title>
        <Sheet.Description>
          {selectedTransfer.created_at ? formatDate(selectedTransfer.created_at) : 'Unknown date'}
        </Sheet.Description>
      </Sheet.Header>

      <dl class="grid gap-4">
        <div class="grid gap-1">
          <dt class="text-xs font-medium uppercase text-muted-foreground">Client</dt>
          <dd class="text-sm">{selectedTransfer.client?.company_name || selectedTransfer.client?.name || '-'}</dd>
        </div>
        <div class="grid gap-1">
          <dt class="text-xs font-medium uppercase text-muted-foreground">Provider</dt>
          <dd class="text-sm">{providerLabel(selectedTransfer.provider)}</dd>
        </div>
        <div class="grid gap-1">
          <dt class="text-xs font-medium uppercase text-muted-foreground">Trigger</dt>
          <dd class="text-sm">{triggerLabel(selectedTransfer.trigger)}</dd>
        </div>
        <div class="grid gap-1">
          <dt class="text-xs font-medium uppercase text-muted-foreground">Status</dt>
          <dd class="flex items-center gap-1.5 text-sm">
            {#if selectedTransfer.status === 'success'}
              <CheckCircle2 class="size-4 text-emerald-500" />
              <span class="font-medium text-emerald-700">Success</span>
            {:else if selectedTransfer.status === 'failed'}
              <XCircle class="size-4 text-destructive" />
              <span class="font-medium text-destructive">Failed</span>
            {:else if selectedTransfer.status === 'processing'}
              <LoaderCircle class="size-4 animate-spin text-blue-600" />
              <span class="font-medium text-blue-700">Processing</span>
            {:else}
              <Clock3 class="size-4 text-amber-500" />
              <span class="font-medium text-amber-700">Queued</span>
            {/if}
          </dd>
        </div>
        <div class="grid gap-1">
          <dt class="text-xs font-medium uppercase text-muted-foreground">Attempts</dt>
          <dd class="text-sm">{selectedTransfer.attempts_count}</dd>
        </div>
        <div class="grid gap-1">
          <dt class="text-xs font-medium uppercase text-muted-foreground">Details</dt>
          <dd class="text-sm break-words">{detailText(selectedTransfer)}</dd>
        </div>
      </dl>

      {#if selectedTransfer.status === 'failed' && selectedTransfer.retryable}
        <div class="mt-6">
          <Button
            type="button"
            variant="secondary"
            class="w-full"
            onclick={() => { retryTransfer(selectedTransfer!.id); sheetOpen = false; }}
            disabled={retryingTransferId === selectedTransfer.id}
          >
            <RotateCcw class="mr-2 size-4" />
            {retryingTransferId === selectedTransfer.id ? 'Retrying...' : 'Retry Transfer'}
          </Button>
        </div>
      {/if}
    {/if}
  </Sheet.Content>
</Sheet.Root>