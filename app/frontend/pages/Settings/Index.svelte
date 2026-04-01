<script lang="ts">
  import { page, router } from "@inertiajs/svelte";
  import { crmAllowed, getSharedAuth } from "@/lib/shared-auth";
  import { sign_up_path } from "@/routes";
  import * as Card from "/components/ui/card";
  import { Button, buttonVariants } from "/components/ui/button";
  import { Input } from "/components/ui/input";
  import * as Sheet from "/components/ui/sheet";

  // Props & state
  let { user, crm_connections = [], available_providers = [] } = $props();
  let deleteConfirmation = $state("");
  let deletingAccount = $state(false);
  let billingLoading = $state(false);
  let billingError = $state<string | null>(null);
  let crmAutoSyncOnPortalSubmit = $state(false);
  let crmPreferenceSaving = $state(false);
  let crmPreferenceError = $state<string | null>(null);
  let oauthLoading = $state(false);
  const csrfToken =
    typeof document === 'undefined'
      ? ''
      : ((document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '');

  const googleConnected = $derived(!!user?.provider);
  const canDeleteAccount = $derived(deleteConfirmation.trim() === "DELETE");
  const sharedAuth = $derived(getSharedAuth($page?.props as Record<string, unknown>));
  const canUseCrm = $derived(crmAllowed(sharedAuth));

  const createdAtLabel = $derived.by(() => {
    if (!user?.created_at) return "—";
    try {
      const date = new Date(user.created_at);
      return date.toLocaleDateString("en-GB", {
        year: "numeric",
        month: "short",
        day: "numeric",
      });
    } catch {
      return user.created_at;
    }
  });

  const subscriptionStatus = $derived.by(() => user?.subscription_status ?? null);

  const subscribed = $derived.by(() => {
    const s = user?.subscription_status;
    return s === "active" || s === "trialing";
  });

  const subscriptionEndsAtLabel = $derived.by(() => {
    if (!user?.subscription_ends_at) return null;
    try {
      const date = new Date(user.subscription_ends_at);
      return date.toLocaleDateString("en-GB", { year: "numeric", month: "short", day: "numeric" });
    } catch {
      return user.subscription_ends_at;
    }
  });

  // CRM State
  const providerNames: Record<string, string> = {
    hubspot: 'HubSpot',
    salesforce: 'Salesforce',
    zoho: 'Zoho CRM'
  };

  let crmLoadingStates = $state<Record<string, boolean>>({});

  const crmConnections = $derived.by(() => {
    const providers = available_providers.length > 0 ? available_providers : ['hubspot', 'salesforce', 'zoho'];
    return providers.map((provider: string) => {
      // Find matching connection from server props
      const conn = crm_connections?.find((c: any) => c.provider === provider && c.status === 'active');
      return {
        id: conn?.id,
        provider,
        name: providerNames[provider] || provider,
        connected: !!conn,
        status: conn?.status,
        loading: !!crmLoadingStates[provider]
      };
    });
  });

  $effect(() => {
    crmAutoSyncOnPortalSubmit = !!user?.crm_auto_sync_on_portal_submit;
  });


  function submitAccountDeletion() {
    if (!canDeleteAccount || deletingAccount) return;

    deletingAccount = true;
    router.delete(sign_up_path(), {
      data: { confirmation: deleteConfirmation.trim() },
      preserveScroll: true,
      onFinish: () => {
        deletingAccount = false;
      },
    });
  }

  async function openBillingPortal() {
    if (billingLoading) return;
    billingLoading = true;
    billingError = null;

    try {
      const csrf = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '';
      const res = await fetch('/subscriptions/billing_portal', {
        method: 'POST',
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error || 'Unable to open billing portal');
      }

      const body = await res.json();
      if (body.url) {
        window.location.href = body.url;
        return;
      }

      throw new Error('No portal url returned');
    } catch (err) {
      billingError = (err as Error).message;
      console.error('Billing portal error', err);
    } finally {
      billingLoading = false;
    }
  }

  function disconnectGoogle() {
    if (oauthLoading) return;
    oauthLoading = true;
    router.delete('/identity/oauth_connection', {
      preserveScroll: true,
      onFinish: () => { oauthLoading = false; },
    });
  }

  function toggleCrmAutoSyncOnPortalSubmit() {
    if (crmPreferenceSaving) return;

    const nextValue = !crmAutoSyncOnPortalSubmit;
    crmAutoSyncOnPortalSubmit = nextValue;
    crmPreferenceError = null;
    crmPreferenceSaving = true;

    router.patch(
      '/settings/crm_preferences',
      {
        settings: {
          crm_auto_sync_on_portal_submit: nextValue,
        },
      },
      {
        preserveScroll: true,
        preserveState: true,
        onError: () => {
          crmAutoSyncOnPortalSubmit = !!user?.crm_auto_sync_on_portal_submit;
          crmPreferenceError = 'Unable to update CRM sync preference.';
        },
        onFinish: () => {
          crmPreferenceSaving = false;
        },
      }
    );
  }

  function toggleCrmConnection(provider: string) {
    const crm = crmConnections.find((c: any) => c.provider === provider);
    if (!crm) return;
    
    if (crm.connected) {
      if (confirm(`Disconnecting will remove authorization. ${crm.name} data will remain intact. Proceed?`)) {
        crmLoadingStates[provider] = true;
        router.delete(`/crm_connections/${crm.id}`, {
          onFinish: () => { crmLoadingStates[provider] = false; }
        });
      }
    } else {
      crmLoadingStates[provider] = true;
      // Use native browser navigation to prevent Inertia XHR headers from interfering with external OAuth state
      window.location.href = `/crm_connections/auth/${provider}`;
    }
  }

  async function testCrmConnection(provider: string) {
    const crm = crmConnections.find((c: any) => c.provider === provider);
    if (!crm || !crm.id) return;
    
    crmLoadingStates[provider] = true;
    try {
      const response = await fetch(`/crm_connections/${crm.id}/test`, {
        method: 'POST',
        headers: { 
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        }
      });
      const result = await response.json();
      if (response.ok) {
        alert(`Test successful for ${crm.name}! Status: ${result.status || 'OK'}`);
      } else {
        alert(`Test failed for ${crm.name}: ${result.error || 'Unknown error'}`);
      }
    } catch (e: any) {
      alert(`Test failed for ${crm.name}: ${e.message}`);
    } finally {
      crmLoadingStates[provider] = false;
    }
  }
</script>

<section class="flex flex-col gap-2">
  <p class="text-sm text-muted-foreground">Account</p>
  <h1 class="text-2xl font-semibold text-foreground">Settings</h1>
  <p class="text-sm text-muted-foreground">Manage your profile and security.</p>
</section>

<section class="mt-6 grid gap-6 lg:grid-cols-[2fr_1fr]">
  <div class="space-y-6">
    <Card.Root>
      <Card.Header>
        <Card.Title>Account information</Card.Title>
        <Card.Description>Basic details tied to your account.</Card.Description>
      </Card.Header>
      <Card.Content class="space-y-4">
        <div class="space-y-2">
          <label class="text-sm font-medium" for="settings-email">Email</label>
          <Input id="settings-email" value={user?.email ?? "—"} disabled />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium" for="settings-created">Account created</label>
          <Input id="settings-created" value={createdAtLabel} disabled />
        </div>

        <!-- Billing section -->
        <div class="space-y-2">
          <div class="text-sm font-medium">Billing</div>
          <div class="flex flex-col gap-2">
            {#if subscriptionStatus}
              <p class="text-sm">Status: <strong>{subscriptionStatus}</strong></p>
              {#if subscriptionEndsAtLabel}
                <p class="text-sm">Ends at: <strong>{subscriptionEndsAtLabel}</strong></p>
              {/if}
              {#if subscribed}
                <Button variant="secondary" class="w-full" onclick={openBillingPortal} disabled={billingLoading}>
                  {#if billingLoading}Opening...{:else}Manage subscription{/if}
                </Button>
              {/if}
            {:else}
              <p class="text-sm text-muted-foreground">No subscription information available.</p>
            {/if}
            {#if billingError}
              <p class="text-sm text-destructive">{billingError}</p>
            {/if}
          </div>
        </div>

      </Card.Content>
    </Card.Root>

    <Card.Root>
      <Card.Header>
        <Card.Title>Sign-in methods</Card.Title>
        <Card.Description>Ways you can sign in to your account.</Card.Description>
      </Card.Header>
      <Card.Content class="space-y-4">
        <!-- Magic link -->
        <div class="flex items-center justify-between gap-3 rounded-lg border bg-background p-3">
          <div>
            <p class="text-sm font-medium">Email magic link</p>
            <p class="text-xs text-muted-foreground">Always available — we email you a sign-in link.</p>
          </div>
          <span class="text-xs text-emerald-600 font-medium">Active</span>
        </div>

        <!-- Google OAuth -->
        <div class="flex items-center justify-between gap-3 rounded-lg border bg-background p-3">
          <div>
            <p class="text-sm font-medium">Google</p>
            <p class="text-xs text-muted-foreground">
              {#if googleConnected}
                Connected — sign in with your Google account.
              {:else}
                Not connected.
              {/if}
            </p>
          </div>
          {#if googleConnected}
            <Button variant="outline" size="sm" onclick={disconnectGoogle} disabled={oauthLoading}>
              {oauthLoading ? 'Disconnecting…' : 'Disconnect'}
            </Button>
          {:else}
            <form action="/auth/google_oauth2" method="post" data-turbo="false">
              <input type="hidden" name="authenticity_token" value={csrfToken} />
              <button
                type="submit"
                class="inline-flex items-center gap-1.5 rounded-md border bg-background px-3 py-1.5 text-xs font-medium shadow-xs hover:bg-accent transition-colors"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="0.9em" height="0.9em" viewBox="0 0 256 262">
                  <path fill="#4285f4" d="M255.878 133.451c0-10.734-.871-18.567-2.756-26.69H130.55v48.448h71.947c-1.45 12.04-9.283 30.172-26.69 42.356l-.244 1.622l38.755 30.023l2.685.268c24.659-22.774 38.875-56.282 38.875-96.027"></path>
                  <path fill="#34a853" d="M130.55 261.1c35.248 0 64.839-11.605 86.453-31.622l-41.196-31.913c-11.024 7.688-25.82 13.055-45.257 13.055c-34.523 0-63.824-22.773-74.269-54.25l-1.531.13l-40.298 31.187l-.527 1.465C35.393 231.798 79.49 261.1 130.55 261.1"></path>
                  <path fill="#fbbc05" d="M56.281 156.37c-2.756-8.123-4.351-16.827-4.351-25.82c0-8.994 1.595-17.697 4.206-25.82l-.073-1.73L15.26 71.312l-1.335.635C5.077 89.644 0 109.517 0 130.55s5.077 40.905 13.925 58.602z"></path>
                  <path fill="#eb4335" d="M130.55 50.479c24.514 0 41.05 10.589 50.479 19.438l36.844-35.974C195.245 12.91 165.798 0 130.55 0C79.49 0 35.393 29.301 13.925 71.947l42.211 32.783c10.59-31.477 39.891-54.251 74.414-54.251"></path>
                </svg>
                Connect Google
              </button>
            </form>
          {/if}
        </div>
      </Card.Content>
    </Card.Root>

    {#if canUseCrm}
    <Card.Root>
      <Card.Header>
        <Card.Title>CRM Integrations</Card.Title>
        <Card.Description>Connect your CRM to automatically export client data.</Card.Description>
      </Card.Header>
      <Card.Content class="space-y-4">
        {#each crmConnections as crm}
          <div class="flex items-center justify-between gap-3 rounded-lg border bg-background p-3">
            <div>
              <p class="text-sm font-medium">{crm.name}</p>
              <p class="text-xs text-muted-foreground">
                {#if crm.connected}
                  Connected — data will be exported automatically.
                {:else}
                  Not connected.
                {/if}
              </p>
            </div>
            <div class="flex items-center gap-2">
              {#if crm.connected}
                <Button variant="outline" size="sm" onclick={() => testCrmConnection(crm.provider)} disabled={crm.loading}>
                  Test
                </Button>
                <Button variant="outline" size="sm" onclick={() => toggleCrmConnection(crm.provider)} disabled={crm.loading}>
                  {crm.loading ? 'Disconnecting…' : 'Disconnect'}
                </Button>
              {:else}
                <Button variant="default" size="sm" onclick={() => toggleCrmConnection(crm.provider)} disabled={crm.loading}>
                  {crm.loading ? 'Connecting…' : 'Connect'}
                </Button>
              {/if}
            </div>
          </div>
        {/each}
      </Card.Content>
    </Card.Root>

    <Card.Root>
      <Card.Header>
        <Card.Title>CRM sync behavior</Card.Title>
        <Card.Description>Choose how validated client portal submissions reach your CRM.</Card.Description>
      </Card.Header>
      <Card.Content class="space-y-4">
        <div class="flex items-start justify-between gap-4 rounded-lg border bg-background p-4">
          <div class="space-y-1">
            <p class="text-sm font-medium">Automatic sync after client portal submission</p>
            <p class="text-xs text-muted-foreground">
              When enabled, validated submissions export automatically. When disabled, you can still push linked clients manually from the client page.
            </p>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={crmAutoSyncOnPortalSubmit}
            aria-label="Toggle CRM automatic sync after client portal submission"
            class={`relative inline-flex h-6 w-11 shrink-0 rounded-full border transition-colors ${crmAutoSyncOnPortalSubmit ? 'border-emerald-600 bg-emerald-600' : 'border-border bg-muted'} ${crmPreferenceSaving ? 'cursor-wait opacity-70' : ''}`}
            onclick={toggleCrmAutoSyncOnPortalSubmit}
            disabled={crmPreferenceSaving}
          >
            <span
              class={`inline-block size-5 rounded-full bg-white shadow-sm transition-transform ${crmAutoSyncOnPortalSubmit ? 'translate-x-5' : 'translate-x-0'}`}
            ></span>
          </button>
        </div>

        <div class="rounded-lg border border-dashed p-4 text-sm">
          {#if crmAutoSyncOnPortalSubmit}
            <p class="font-medium text-foreground">Validated portal submissions sync automatically.</p>
            <p class="mt-1 text-muted-foreground">
              Manual CRM export remains available from the client page. Editing a CRM-linked client from the back office still pushes profile changes automatically.
            </p>
          {:else}
            <p class="font-medium text-foreground">Portal submissions stay local until you trigger a manual CRM update.</p>
            <p class="mt-1 text-muted-foreground">
              Use the CRM export button on the client page when you want to push the latest linked-client data yourself.
            </p>
          {/if}
        </div>

        {#if crmPreferenceError}
          <p class="text-sm text-destructive">{crmPreferenceError}</p>
        {/if}
      </Card.Content>
    </Card.Root>
    {/if}

    <Card.Root class="border-destructive/40">
      <Card.Header>
        <Card.Title class="text-destructive">Delete account</Card.Title>
        <Card.Description>
          This action is permanent and removes your access immediately.
        </Card.Description>
      </Card.Header>
      <Card.Content class="space-y-4">
        <p class="text-sm text-muted-foreground">
          Deleting your account will permanently remove all associated clients and forms.
          This cannot be undone.
        </p>
        <Sheet.Root>
          <Sheet.Trigger class={buttonVariants({ variant: "destructive" })}>
            Delete account
          </Sheet.Trigger>
          <Sheet.Content side="right" class="w-full sm:max-w-lg">
            <Sheet.Header>
              <Sheet.Title>Confirm account deletion</Sheet.Title>
              <Sheet.Description>
                This will delete your account and all associated clients and forms.
                This action cannot be undone.
              </Sheet.Description>
            </Sheet.Header>
            <div class="mt-6 space-y-4">
              <p class="text-sm text-muted-foreground">
                Type DELETE to confirm. This helps prevent accidental deletions.
              </p>
              <div class="space-y-2">
                <label class="text-sm font-medium" for="delete-confirm">Confirmation</label>
                <Input id="delete-confirm" placeholder="DELETE" bind:value={deleteConfirmation} />
              </div>
            </div>
            <Sheet.Footer class="mt-6">
              <Sheet.Close class={buttonVariants({ variant: "secondary" })}>
                Cancel
              </Sheet.Close>
              <button
                type="button"
                class={buttonVariants({ variant: "destructive" })}
                onclick={submitAccountDeletion}
                disabled={!canDeleteAccount || deletingAccount}
              >
                Permanently delete
              </button>
            </Sheet.Footer>
          </Sheet.Content>
        </Sheet.Root>
      </Card.Content>
    </Card.Root>
  </div>

  <Card.Root>
    <Card.Header>
      <Card.Title>Security checklist</Card.Title>
      <Card.Description>Recommended actions to keep your account safe.</Card.Description>
    </Card.Header>
    <Card.Content class="space-y-3">
      <div class="flex items-start gap-3 rounded-lg border border-border bg-background p-3">
        <div class="mt-1 size-2 rounded-full bg-emerald-500"></div>
        <div>
          <p class="text-sm font-medium">Password updated</p>
          <p class="text-xs text-muted-foreground">Last updated 3 days ago.</p>
        </div>
      </div>
      <div class="flex items-start gap-3 rounded-lg border border-border bg-background p-3">
        <div class="mt-1 size-2 rounded-full bg-amber-500"></div>
        <div>
          <p class="text-sm font-medium">Enable 2FA</p>
          <p class="text-xs text-muted-foreground">Add an extra layer of security.</p>
        </div>
      </div>
      <Button variant="secondary" class="w-full">Review security settings</Button>
    </Card.Content>
  </Card.Root>
</section>
