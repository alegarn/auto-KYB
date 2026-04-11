<script lang="ts">
  import { page, router } from "@inertiajs/svelte";
  import { untrack } from "svelte";
  import { slide } from "svelte/transition";
  import { cubicInOut } from "svelte/easing";
  import { crmAllowed, getSharedAuth } from "@/lib/shared-auth";
  import {
    sign_up_path,
    identity_oauth_connection_path,
    settings_crm_preferences_path,
    settings_client_invitation_email_path,
    subscriptions_billing_portal_path,
    crm_connection_path,
    auth_crm_connections_path,
    test_crm_connection_path,
  } from "@/routes";
  import * as Card from "/components/ui/card";
  import { Button, buttonVariants } from "/components/ui/button";
  import { Input } from "/components/ui/input";
  import * as Sheet from "/components/ui/sheet";
  import {
    ALLOWED_VARIABLES,
    DEFAULT_SUBJECT,
    DEFAULT_BODY,
    PREVIEW_VARIABLES,
    renderTemplate,
    type InviteEmailSetting,
  } from "@/lib/invite-email";
  import {
    buildCrmConnectionList,
    formatDateLabel,
    isSubscribed,
    fetchBillingPortalUrl,
    testCrmConnectionApi,
  } from "@/lib/settings-api";

  // ── Props ──────────────────────────────────────────────────────────
  let {
    user,
    crm_connections = [],
    available_providers = [],
    client_invitation_email_setting = {
      auto_send: false,
      subject_template: null,
      body_template: null,
    } as InviteEmailSetting,
    errors = {},
  } = $props();

  const csrfToken =
    typeof document === 'undefined'
      ? ''
      : ((document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || '');

  // ── Expandable Sections State ─────────────────────────────────────
  let accountExpanded = $state(false);
  let signinExpanded = $state(false);
  let crmExpanded = $state(false);
  let crmSyncExpanded = $state(false);
  let inviteExpanded = $state(false);

  // ── Computing Labels ────────────────────────────────────────────────
  const createdAtLabel = $derived(formatDateLabel(user?.created_at));

  // ── Billing ───────────────────────────────────────────────────────
  let billingLoading = $state(false);
  let billingError = $state<string | null>(null);
  const subscriptionStatus = $derived(user?.subscription_status ?? null);
  const subscribed = $derived(isSubscribed(user?.subscription_status));
  const subscriptionEndsAtLabel = $derived(
    user?.subscription_ends_at ? formatDateLabel(user.subscription_ends_at) : null,
  );

  // ── Google ────────────────────────────────────────────────────────
  const googleConnected = $derived(!!user?.provider);
  let oauthLoading = $state(false);

  // ── Delete Acc ───────────────────────────────────────────────────
  let deleteConfirmation = $state('');
  let deletingAccount = $state(false);
  const canDeleteAccount = $derived(deleteConfirmation.trim() === 'DELETE');

  const sharedAuth = $derived(getSharedAuth($page?.props as Record<string, unknown>));
  const canUseCrm = $derived(crmAllowed(sharedAuth));

  // ── CRM connections ───────────────────────────────────────────────
  let crmLoadingStates = $state<Record<string, boolean>>({});
  const crmConnections = $derived(
    buildCrmConnectionList(available_providers, crm_connections, crmLoadingStates),
  );

  let crmAutoSyncOnPortalSubmit = $state(false);
  let crmPreferenceSaving = $state(false);
  let crmPreferenceError = $state<string | null>(null);
  $effect(() => {
    crmAutoSyncOnPortalSubmit = !!user?.crm_auto_sync_on_portal_submit;
  });

  // ── Invite email ──────────────────────────────────────────────────
  let inviteAutoSend = $state(untrack(() => !!client_invitation_email_setting?.auto_send));
  let inviteSubject = $state(untrack(() => client_invitation_email_setting?.subject_template ?? ''));
  let inviteBody = $state(untrack(() => client_invitation_email_setting?.body_template ?? ''));
  let inviteSaving = $state(false);
  let inviteError = $state<string | null>(null);
  const previewSubject = $derived(renderTemplate(inviteSubject || DEFAULT_SUBJECT, PREVIEW_VARIABLES));
  const previewBody = $derived(renderTemplate(inviteBody || DEFAULT_BODY, PREVIEW_VARIABLES));
  $effect(() => {
    inviteAutoSend = !!client_invitation_email_setting?.auto_send;
    inviteSubject = client_invitation_email_setting?.subject_template ?? '';
    inviteBody = client_invitation_email_setting?.body_template ?? '';
  });

  // ── Handlers ──────────────────────────────────────────────────────

  async function openBillingPortal() {
    if (billingLoading) return;
    billingLoading = true;
    billingError = null;
    try {
      const url = await fetchBillingPortalUrl(csrfToken, subscriptions_billing_portal_path());
      window.location.href = url;
    } catch (err) {
      billingError = (err as Error).message;
    } finally {
      billingLoading = false;
    }
  }

  function disconnectGoogle() {
    if (oauthLoading) return;
    oauthLoading = true;
    router.delete(identity_oauth_connection_path(), { preserveScroll: true, onFinish: () => { oauthLoading = false; } });
  }

  function submitAccountDeletion() {
    if (!canDeleteAccount || deletingAccount) return;
    deletingAccount = true;
    router.delete(sign_up_path(), {
      data: { confirmation: deleteConfirmation.trim() },
      preserveScroll: true,
      onFinish: () => { deletingAccount = false; },
    });
  }

  function toggleCrmAutoSyncOnPortalSubmit() {
    if (crmPreferenceSaving) return;
    const nextValue = !crmAutoSyncOnPortalSubmit;
    crmAutoSyncOnPortalSubmit = nextValue;
    crmPreferenceError = null;
    crmPreferenceSaving = true;
    router.patch(
      settings_crm_preferences_path(),
      { settings: { crm_auto_sync_on_portal_submit: nextValue } },
      {
        preserveScroll: true,
        preserveState: true,
        onError: () => {
          crmAutoSyncOnPortalSubmit = !!user?.crm_auto_sync_on_portal_submit;
          crmPreferenceError = 'Unable to update CRM sync preference.';
        },
        onFinish: () => { crmPreferenceSaving = false; },
      },
    );
  }

  function toggleCrmConnection(provider: string) {
    const crm = crmConnections.find((c) => c.provider === provider);
    if (!crm) return;
    if (crm.connected) {
      if (confirm(`Disconnecting will remove authorization. ${crm.name} data will remain intact. Proceed?`)) {
        crmLoadingStates[provider] = true;
        router.delete(crm_connection_path(crm.id!), { onFinish: () => { crmLoadingStates[provider] = false; } });
      }
    } else {
      crmLoadingStates[provider] = true;
      window.location.href = auth_crm_connections_path(provider);
    }
  }

  async function testCrmConnection(provider: string) {
    const crm = crmConnections.find((c) => c.provider === provider);
    if (!crm || !crm.id) return;
    crmLoadingStates[provider] = true;
    try {
      const result = await testCrmConnectionApi(test_crm_connection_path(crm.id), csrfToken);
      alert(result.ok ? `Test successful for ${crm.name}! Status: ${result.message}` : `Test failed for ${crm.name}: ${result.message}`);
    } catch (e: any) {
      alert(`Test failed for ${crm.name}: ${e.message}`);
    } finally {
      crmLoadingStates[provider] = false;
    }
  }

  function insertVariable(field: 'subject' | 'body', variable: string) {
    if (field === 'subject') inviteSubject += variable;
    else inviteBody += variable;
  }

  function saveInviteEmailSettings() {
    if (inviteSaving) return;
    inviteSaving = true;
    inviteError = null;
    router.patch(
      settings_client_invitation_email_path(),
      { client_invitation_email_setting: { auto_send: inviteAutoSend, subject_template: inviteSubject || null, body_template: inviteBody || null } },
      { preserveScroll: true, onError: (errs: any) => { inviteError = typeof errs === 'string' ? errs : 'Error saving'; }, onFinish: () => { inviteSaving = false; } }
    );
  }
</script>

<section class="flex flex-col gap-2">
  <p class="text-sm text-muted-foreground">Account</p>
  <h1 class="text-2xl font-semibold text-foreground">Settings</h1>
  <p class="text-sm text-muted-foreground">Manage your profile and security.</p>
</section>

<section class="mt-6 grid gap-4">
  <div class="space-y-4">
    <!-- Account Information -->
    <Card.Root>
      <div 
        class="flex items-center justify-between p-6 cursor-pointer hover:bg-muted/30 transition-colors rounded-xl"
        onclick={() => accountExpanded = !accountExpanded}
        role="button"
        tabindex="0"
        onkeydown={(e) => e.key === 'Enter' && (accountExpanded = !accountExpanded)}
      >
        <div>
          <h3 class="font-semibold leading-none tracking-tight">Account information</h3>
          {#if !accountExpanded}
            <div transition:slide={{ duration: 200, easing: cubicInOut }}>
              <p class="text-sm text-muted-foreground mt-1">Email: {user?.email ?? "—"} • {subscriptionStatus ? `Status: ${subscriptionStatus}` : 'No active subscription'}</p>
            </div>
          {/if}
        </div>
        <Button variant="outline" size="sm" class="pointer-events-none">{accountExpanded ? 'Close' : 'Manage'}</Button>
      </div>

      {#if accountExpanded}
        <div transition:slide={{ duration: 200, easing: cubicInOut }}>
          <Card.Content class="space-y-4 pb-6 pt-0">
            <div class="h-px bg-border mb-4 w-full"></div>
            <div class="space-y-2">
              <label class="text-sm font-medium" for="settings-email">Email</label>
              <Input id="settings-email" value={user?.email ?? "—"} disabled />
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium" for="settings-created">Account created</label>
              <Input id="settings-created" value={createdAtLabel} disabled />
            </div>
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
        </div>
      {/if}
    </Card.Root>

    <!-- Sign-in Methods -->
    <Card.Root>
      <div 
        class="flex items-center justify-between p-6 cursor-pointer hover:bg-muted/30 transition-colors rounded-xl"
        onclick={() => signinExpanded = !signinExpanded}
        role="button"
        tabindex="0"
        onkeydown={(e) => e.key === 'Enter' && (signinExpanded = !signinExpanded)}
      >
        <div>
          <h3 class="font-semibold leading-none tracking-tight">Sign-in methods</h3>
          {#if !signinExpanded}
            <div transition:slide={{ duration: 200, easing: cubicInOut }}>
              <p class="text-sm text-muted-foreground mt-1">Google: {googleConnected ? 'Connected' : 'Not connected'} • Magic Link: Active</p>
            </div>
          {/if}
        </div>
        <Button variant="outline" size="sm" class="pointer-events-none">{signinExpanded ? 'Close' : 'Manage'}</Button>
      </div>

      {#if signinExpanded}
        <div transition:slide={{ duration: 200, easing: cubicInOut }}>
          <Card.Content class="space-y-4 pb-6 pt-0">
            <div class="h-px bg-border mb-4 w-full"></div>
            <div class="flex items-center justify-between gap-3 rounded-lg border bg-background p-3">
              <div>
                <p class="text-sm font-medium">Email magic link</p>
                <p class="text-xs text-muted-foreground">Always available — we email you a sign-in link.</p>
              </div>
              <span class="text-xs text-emerald-600 font-medium">Active</span>
            </div>
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
                    aria-label="Connect with Google"
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
        </div>
      {/if}
    </Card.Root>

    <!-- CRM Integrations -->
    {#if canUseCrm}
      <Card.Root data-onboarding-tutorial="crm-integrations">
        <div 
          class="flex items-center justify-between p-6 cursor-pointer hover:bg-muted/30 transition-colors rounded-xl"
          onclick={() => crmExpanded = !crmExpanded}
          role="button"
          tabindex="0"
          onkeydown={(e) => e.key === 'Enter' && (crmExpanded = !crmExpanded)}
        >
          <div>
            <h3 class="font-semibold leading-none tracking-tight">CRM Integrations</h3>
            {#if !crmExpanded}
              <div transition:slide={{ duration: 200, easing: cubicInOut }}>
                <p class="text-sm text-muted-foreground mt-1">
                  {#if crmConnections.filter(c => c.connected).length > 0}
                    {crmConnections.filter(c => c.connected).map(c => c.name).join(', ')} connected
                  {:else}
                    No CRM connected
                  {/if}
                </p>
              </div>
            {/if}
          </div>
          <Button variant="outline" size="sm" class="pointer-events-none">{crmExpanded ? 'Close' : 'Manage'}</Button>
        </div>

        {#if crmExpanded}
          <div transition:slide={{ duration: 200, easing: cubicInOut }}>
            <Card.Content class="space-y-4 pb-6 pt-0">
              <div class="h-px bg-border mb-4 w-full"></div>
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
                      <Button variant="outline" size="sm" onclick={(e) => { e.stopPropagation(); testCrmConnection(crm.provider); }} disabled={crm.loading}>Test</Button>
                      <Button variant="outline" size="sm" onclick={(e) => { e.stopPropagation(); toggleCrmConnection(crm.provider); }} disabled={crm.loading}>
                        {crm.loading ? 'Disconnecting…' : 'Disconnect'}
                      </Button>
                    {:else}
                      <Button variant="default" size="sm" data-onboarding-tutorial="crm-connect-button" onclick={(e) => { e.stopPropagation(); toggleCrmConnection(crm.provider); }} disabled={crm.loading}>
                        {crm.loading ? 'Connecting…' : 'Connect'}
                      </Button>
                    {/if}
                  </div>
                </div>
              {/each}
            </Card.Content>
          </div>
        {/if}
      </Card.Root>

      <!-- CRM Sync Behavior -->
      <Card.Root>
        <div 
          class="flex items-center justify-between p-6 cursor-pointer hover:bg-muted/30 transition-colors rounded-xl"
          onclick={() => crmSyncExpanded = !crmSyncExpanded}
          role="button"
          tabindex="0"
          onkeydown={(e) => e.key === 'Enter' && (crmSyncExpanded = !crmSyncExpanded)}
        >
          <div>
            <h3 class="font-semibold leading-none tracking-tight">CRM sync behavior</h3>
            {#if !crmSyncExpanded}
              <div transition:slide={{ duration: 200, easing: cubicInOut }}>
                <p class="text-sm text-muted-foreground mt-1">Automatic sync: {crmAutoSyncOnPortalSubmit ? 'Enabled' : 'Disabled'}</p>
              </div>
            {/if}
          </div>
          <Button variant="outline" size="sm" class="pointer-events-none">{crmSyncExpanded ? 'Close' : 'Manage'}</Button>
        </div>

        {#if crmSyncExpanded}
          <div transition:slide={{ duration: 200, easing: cubicInOut }}>
            <Card.Content class="space-y-4 pb-6 pt-0">
              <div class="h-px bg-border mb-4 w-full"></div>
              <div class="flex items-start justify-between gap-4 rounded-lg border bg-background p-4">
                <div class="space-y-1">
                  <p class="text-sm font-medium">Automatic sync after client portal submission</p>
                  <p class="text-xs text-muted-foreground">
                    When enabled, validated submissions export automatically. When disabled, push linked clients manually.
                  </p>
                </div>
                <button 
                  type="button" 
                  role="switch" 
                  aria-checked={crmAutoSyncOnPortalSubmit} 
                  aria-label="Toggle automatic CRM sync"
                  class={`relative inline-flex h-6 w-11 shrink-0 rounded-full border transition-colors ${crmAutoSyncOnPortalSubmit ? 'border-emerald-600 bg-emerald-600' : 'border-border bg-muted'} ${crmPreferenceSaving ? 'cursor-wait opacity-70' : ''}`} 
                  onclick={(e) => { e.stopPropagation(); toggleCrmAutoSyncOnPortalSubmit(); }} 
                  disabled={crmPreferenceSaving}
                >
                  <span class={`inline-block size-5 rounded-full bg-white shadow-sm transition-transform ${crmAutoSyncOnPortalSubmit ? 'translate-x-5' : 'translate-x-0'}`}></span>
                </button>
              </div>
              <div class="rounded-lg border border-dashed p-4 text-sm">
                {#if crmAutoSyncOnPortalSubmit}
                  <p class="font-medium text-foreground">Validated portal submissions sync automatically.</p>
                  <p class="mt-1 text-muted-foreground">Manual CRM export remains available from the client page.</p>
                {:else}
                  <p class="font-medium text-foreground">Portal submissions stay local until you trigger a manual CRM update.</p>
                  <p class="mt-1 text-muted-foreground">Use the CRM export button on the client page.</p>
                {/if}
              </div>
              {#if crmPreferenceError}<p class="text-sm text-destructive">{crmPreferenceError}</p>{/if}
            </Card.Content>
          </div>
        {/if}
      </Card.Root>
    {/if}

    <!-- Client Invite Email -->
    <Card.Root>
      <div 
        class="flex items-center justify-between p-6 cursor-pointer hover:bg-muted/30 transition-colors rounded-xl"
        onclick={() => inviteExpanded = !inviteExpanded}
        role="button"
        tabindex="0"
        onkeydown={(e) => e.key === 'Enter' && (inviteExpanded = !inviteExpanded)}
      >
        <div>
          <h3 class="font-semibold leading-none tracking-tight">Client invite email and template</h3>
          {#if !inviteExpanded}
            <div transition:slide={{ duration: 200, easing: cubicInOut }}>
              <p class="text-sm text-muted-foreground mt-1">Auto-send: {inviteAutoSend ? 'Enabled' : 'Disabled'}</p>
            </div>
          {/if}
        </div>
        <Button variant="outline" size="sm" class="pointer-events-none">{inviteExpanded ? 'Close' : 'Manage'}</Button>
      </div>

      {#if inviteExpanded}
        <div transition:slide={{ duration: 200, easing: cubicInOut }}>
          <Card.Content class="space-y-4 pb-6 pt-0">
            <div class="h-px bg-border mb-4 w-full"></div>
            <div class="flex items-start justify-between gap-4 rounded-lg border bg-background p-4">
              <div class="space-y-1">
                <p class="text-sm font-medium">Send client portal invite automatically</p>
                <p class="text-xs text-muted-foreground">When enabled, the invite email is sent automatically if the client has an email address.</p>
              </div>
              <button 
                type="button" 
                role="switch" 
                aria-checked={inviteAutoSend} 
                aria-label="Toggle automatic client invite email"
                class={`relative inline-flex h-6 w-11 shrink-0 rounded-full border transition-colors ${inviteAutoSend ? 'border-emerald-600 bg-emerald-600' : 'border-border bg-muted'}`} 
                onclick={(e) => { e.stopPropagation(); inviteAutoSend = !inviteAutoSend; }}
              >
                <span class={`inline-block size-5 rounded-full bg-white shadow-sm transition-transform ${inviteAutoSend ? 'translate-x-5' : 'translate-x-0'}`}></span>
              </button>
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium" for="invite-subject">Subject template</label>
              <Input id="invite-subject" placeholder="Your Quick KYB secure form access" bind:value={inviteSubject} onclick={(e) => e.stopPropagation()} />
              <div class="flex flex-wrap gap-1">
                {#each ALLOWED_VARIABLES as v}
                  <button type="button" class="rounded bg-muted px-2 py-0.5 text-xs font-mono hover:bg-muted/80" onclick={(e) => { e.stopPropagation(); insertVariable('subject', v); }}>{v}</button>
                {/each}
              </div>
              {#if errors?.subject_template}<p class="text-sm text-destructive">{errors.subject_template}</p>{/if}
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium" for="invite-body">Body template</label>
              <textarea id="invite-body" class="w-full min-h-[160px] rounded-md border border-input bg-background px-3 py-2 text-sm" placeholder={"Hello {{client_name}}..."} bind:value={inviteBody} onclick={(e) => e.stopPropagation()}></textarea>
              <div class="flex flex-wrap gap-1">
                {#each ALLOWED_VARIABLES as v}
                  <button type="button" class="rounded bg-muted px-2 py-0.5 text-xs font-mono hover:bg-muted/80" onclick={(e) => { e.stopPropagation(); insertVariable('body', v); }}>{v}</button>
                {/each}
              </div>
              {#if errors?.body_template}<p class="text-sm text-destructive">{errors.body_template}</p>{/if}
            </div>
            <div class="rounded-lg border border-dashed p-4 space-y-2">
              <p class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Preview (sample data)</p>
              <p class="text-sm"><strong>Subject:</strong> {previewSubject}</p>
              <div class="mt-2 whitespace-pre-wrap text-sm text-muted-foreground bg-muted/20 rounded p-3">{previewBody}</div>
            </div>
            <Button onclick={(e) => { e.stopPropagation(); saveInviteEmailSettings(); }} disabled={inviteSaving}>{inviteSaving ? 'Saving…' : 'Save invite email settings'}</Button>
            {#if inviteError}<p class="text-sm text-destructive">{inviteError}</p>{/if}
          </Card.Content>
        </div>
      {/if}
    </Card.Root>

    <!-- Delete Account (Always visible / pure red action) -->
    <Card.Root class="border-destructive/40">
      <Card.Header>
        <Card.Title class="text-destructive">Delete account</Card.Title>
        <Card.Description>This action is permanent and removes your access immediately.</Card.Description>
      </Card.Header>
      <Card.Content class="space-y-4">
        <p class="text-sm text-muted-foreground">
          Deleting your account will permanently remove all associated clients and forms. This cannot be undone.
        </p>
        <Sheet.Root>
          <Sheet.Trigger class={buttonVariants({ variant: "destructive" })}>Delete account</Sheet.Trigger>
          <Sheet.Content side="right" class="w-full sm:max-w-lg">
            <Sheet.Header>
              <Sheet.Title>Confirm account deletion</Sheet.Title>
              <Sheet.Description>This will delete your account and all associated clients and forms. This action cannot be undone.</Sheet.Description>
            </Sheet.Header>
            <div class="mt-6 space-y-4">
              <p class="text-sm text-muted-foreground">Type DELETE to confirm. This helps prevent accidental deletions.</p>
              <div class="space-y-2">
                <label class="text-sm font-medium" for="delete-confirm">Confirmation</label>
                <Input id="delete-confirm" placeholder="DELETE" bind:value={deleteConfirmation} />
              </div>
            </div>
            <Sheet.Footer class="mt-6">
              <Sheet.Close class={buttonVariants({ variant: "secondary" })}>Cancel</Sheet.Close>
              <button type="button" class={buttonVariants({ variant: "destructive" })} onclick={submitAccountDeletion} disabled={!canDeleteAccount || deletingAccount}>Permanently delete</button>
            </Sheet.Footer>
          </Sheet.Content>
        </Sheet.Root>
      </Card.Content>
    </Card.Root>
  </div>
</section>
