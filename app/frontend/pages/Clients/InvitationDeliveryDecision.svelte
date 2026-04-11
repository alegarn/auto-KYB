<script lang="ts">
  import { page } from '@inertiajs/svelte';
  import Button from '@/components/ui/button/button.svelte';
  import Modal from '@/components/ui/modal.svelte';
  import { clients_path } from '@/routes';

  let { client_form_id, client, form, has_email, auto_send = false, flash_message = null } = $props();

  let showModal = $state(true);
  let sending = $state(false);
  let autoSendStarted = $state(false);
  let autoSendBlocked = $state(false);

  const alertMessage = $derived($page.props.flash?.alert || flash_message);
  const shouldAutoSend = $derived(Boolean(auto_send && has_email && !alertMessage && !autoSendBlocked));
  const showSendingState = $derived(Boolean(shouldAutoSend || sending));

  // Deferred import — module is only fetched when the user acts (or auto_send fires)
  type InvitationDeliveryLib = typeof import('@/lib/invitation-delivery');
  let invitationLib: InvitationDeliveryLib | null = null;

  async function getLib(): Promise<InvitationDeliveryLib> {
    if (!invitationLib) {
      invitationLib = await import('@/lib/invitation-delivery');
    }
    return invitationLib;
  }

  // Auto-send once on initial render when the visit is still clean.
  $effect(() => {
    if (!shouldAutoSend || autoSendStarted) return;

    autoSendStarted = true;
    void handleSendNow();
  });

  async function handleSendNow() {
    if (sending || !has_email) return;

    sending = true;

    try {
      const lib = await getLib();
      lib.sendInvitation(client_form_id, {
        onFinish: () => { sending = false; },
      });
    } catch {
      autoSendBlocked = true;
      sending = false;
      showModal = true;
    }
  }

  async function handleNotNow() {
    if (sending) return;

    try {
      const lib = await getLib();
      lib.skipInvitation(client_form_id);
    } catch {
      showModal = true;
    }
  }
</script>

<main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8 flex items-center justify-center">
  <section class="w-full max-w-lg">
    {#if alertMessage}
      <div class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700" role="alert">
        <span>{alertMessage}</span>
      </div>
    {/if}

    {#if showSendingState}
      <div class="rounded-lg border border-border bg-background p-6 shadow-sm" role="status" aria-live="polite" aria-busy="true">
        <h2 class="text-lg font-semibold text-foreground">Sending portal access…</h2>
        <p class="mt-2 text-sm text-muted-foreground">
          Quick KYB is sending the client portal link and one-time password to
          <strong class="text-foreground">{client?.email}</strong>.
        </p>
        <p class="mt-2 text-sm text-muted-foreground">
          You will continue to the password reveal screen as soon as delivery finishes.
        </p>

        <div class="mt-4 rounded-md bg-muted/30 p-3 text-xs text-muted-foreground">
          <p><strong>Client:</strong> {client?.name}</p>
          <p><strong>Form:</strong> {form?.name}</p>
          <p><strong>Email:</strong> {client?.email}</p>
        </div>

        <div class="mt-4 h-1.5 overflow-hidden rounded-full bg-muted">
          <div class="h-full w-1/3 animate-pulse rounded-full bg-primary"></div>
        </div>
      </div>
    {:else}
      <Modal
        bind:showModal
        title="Send portal access now?"
        confirmText={sending ? 'Sending…' : 'Send now'}
        confirmDisabled={!has_email || sending}
        confirmTone="default"
        onConfirm={handleSendNow}
        onClose={handleNotNow}
      >
        {#if has_email}
          <p class="text-sm text-muted-foreground">
            Quick KYB can send the client portal link and one-time password to
            <strong class="text-foreground">{client?.email}</strong> now.
          </p>
          <p class="mt-2 text-sm text-muted-foreground">
            You will still see the credentials on the next screen.
          </p>
        {:else}
          <p class="text-sm text-muted-foreground">
            This client does not have an email address yet, so Quick KYB cannot send the portal access automatically.
          </p>
          <p class="mt-2 text-sm text-muted-foreground">
            You can continue to the one-time reveal and share it manually.
          </p>
        {/if}

        <div class="mt-3 rounded-md bg-muted/30 p-3 text-xs text-muted-foreground">
          <p><strong>Client:</strong> {client?.name}</p>
          <p><strong>Form:</strong> {form?.name}</p>
          {#if has_email}
            <p><strong>Email:</strong> {client?.email}</p>
          {/if}
        </div>
      </Modal>

      <!-- Fallback when modal is closed unexpectedly -->
      {#if !showModal}
        <div class="rounded-lg border border-border bg-background p-6">
          <h2 class="text-lg font-semibold text-foreground">Send portal access now?</h2>

          {#if has_email}
            <p class="mt-2 text-sm text-muted-foreground">
              Send the client portal link and one-time password to <strong class="text-foreground">{client?.email}</strong>.
            </p>
          {:else}
            <p class="mt-2 text-sm text-muted-foreground">
              No email address available. Continue to the reveal page to share credentials manually.
            </p>
          {/if}

          <div class="mt-4 flex gap-3">
            {#if has_email}
              <Button onclick={handleSendNow} disabled={sending}>
                {sending ? 'Sending…' : 'Send now'}
              </Button>
            {/if}
            <Button variant="secondary" onclick={handleNotNow} disabled={sending}>
              Not now
            </Button>
            <Button href={clients_path()} variant="outline" disabled={sending}>Cancel</Button>
          </div>
        </div>
      {/if}
    {/if}
  </section>
</main>
