<script lang="ts">
  let { retention_days = 3 }: { retention_days?: number } = $props();
</script>

<svelte:head>
  <title>Privacy - Quick KYB</title>
  <meta
    name="description"
    content="Quick KYB privacy information, including temporary CRM transfer retention and operational data handling."
  />
</svelte:head>

<section class="py-20 md:py-28">
  <div class="mx-auto max-w-4xl px-6">
    <div class="max-w-3xl">
      <p class="text-sm font-medium uppercase tracking-[0.2em] text-muted-foreground">Privacy</p>
      <h1 class="mt-4 text-4xl font-semibold tracking-tight">How Quick KYB handles CRM transfer data</h1>
      <p class="mt-4 text-base leading-7 text-muted-foreground">
        Quick KYB stores a short-lived operational record when data is queued for export to a connected CRM.
        That record exists to troubleshoot failures, verify delivery, and support manual retry.
      </p>
    </div>

    <div class="mt-12 space-y-8 rounded-2xl border bg-background p-8 shadow-sm">
      <section>
        <h2 class="text-xl font-semibold">What is stored temporarily</h2>
        <p class="mt-3 text-sm leading-7 text-muted-foreground">
          We store the transfer timestamp, provider, trigger, delivery status, retry count, and a minimal internal context required to run the transfer.
          We do not expose internal request context or payload snapshots in the user interface.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-semibold">Retention period</h2>
        <p class="mt-3 text-sm leading-7 text-muted-foreground">
          CRM transfer records are retained for a maximum of {retention_days} days. This applies to successful and failed transfers.
          Older records are deleted automatically as part of routine cleanup.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-semibold">Why retention is limited</h2>
        <p class="mt-3 text-sm leading-7 text-muted-foreground">
          These records are operational artifacts, not a long-term customer data store. Limiting retention reduces the amount of temporary CRM troubleshooting data kept inside Quick KYB while still giving users a short window to review failures and queue retries.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-semibold">User-facing history</h2>
        <p class="mt-3 text-sm leading-7 text-muted-foreground">
          The CRM Transfers page shows only the minimal operational details needed to understand whether a transfer succeeded, failed, or is still processing. Hidden internal payload data is not displayed there.
        </p>
      </section>
    </div>
  </div>
</section>