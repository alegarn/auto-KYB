<script lang="ts">
  import { dashboard_path } from "@/routes";
  import Button from '@/components/ui/button/button.svelte';
  import * as Table from "/components/ui/table";
  import { CheckCircle2, XCircle, Clock } from "@lucide/svelte";

  // Dummy data for transfers
  const transfers = [
    { id: 1, date: '2026-02-27T10:30:00Z', client: 'Acme Corp', crm: 'HubSpot', status: 'success', error: null },
    { id: 2, date: '2026-02-27T10:30:00Z', client: 'Acme Corp', crm: 'Salesforce', status: 'failed', error: 'API rate limit exceeded' },
    { id: 3, date: '2026-02-26T14:15:00Z', client: 'Globex Inc', crm: 'HubSpot', status: 'success', error: null },
    { id: 4, date: '2026-02-26T09:00:00Z', client: 'Initech', crm: 'Zoho CRM', status: 'pending', error: null },
  ];

  function formatDate(iso: string) {
    return new Date(iso).toLocaleString(undefined, {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  }
</script>

<section class="p-6 w-full">
  <div class="w-full max-w-5xl mx-auto">
    <header class="mb-6">
      <h1 class="text-2xl font-semibold">CRM Transfer History</h1>
      <p class="text-sm text-muted-foreground">View the status of data exports to your connected CRMs.</p>
    </header>

    <div class="rounded-md border bg-background">
      <Table.Root>
        <Table.Header>
          <Table.Row>
            <Table.Head>Date</Table.Head>
            <Table.Head>Client</Table.Head>
            <Table.Head>CRM</Table.Head>
            <Table.Head>Status</Table.Head>
            <Table.Head>Details</Table.Head>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {#each transfers as transfer}
            <Table.Row>
              <Table.Cell class="font-medium">{formatDate(transfer.date)}</Table.Cell>
              <Table.Cell>{transfer.client}</Table.Cell>
              <Table.Cell>{transfer.crm}</Table.Cell>
              <Table.Cell>
                <div class="flex items-center gap-1.5">
                  {#if transfer.status === 'success'}
                    <CheckCircle2 class="size-4 text-emerald-500" />
                    <span class="text-sm font-medium text-emerald-700">Success</span>
                  {:else if transfer.status === 'failed'}
                    <XCircle class="size-4 text-destructive" />
                    <span class="text-sm font-medium text-destructive">Failed</span>
                  {:else}
                    <Clock class="size-4 text-amber-500" />
                    <span class="text-sm font-medium text-amber-700">Pending</span>
                  {/if}
                </div>
              </Table.Cell>
              <Table.Cell class="text-sm text-muted-foreground">
                {#if transfer.error}
                  <span class="text-destructive">{transfer.error}</span>
                {:else if transfer.status === 'success'}
                  Data and files transferred
                {:else}
                  Waiting for retry...
                {/if}
              </Table.Cell>
            </Table.Row>
          {/each}
        </Table.Body>
      </Table.Root>
    </div>

    <div class="mt-6">
      <Button href={dashboard_path()} variant="outline">Back to dashboard</Button>
    </div>
  </div>
</section>