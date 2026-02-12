<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import { sign_up_path } from "@/routes";
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import * as Card from "/components/ui/card";
  import { Button, buttonVariants } from "/components/ui/button";
  import { Input } from "/components/ui/input";
  import * as Sheet from "/components/ui/sheet";

  let { children, user, session_id } = $props();
  let deleteConfirmation = $state("");
  let deletingAccount = $state(false);

  const canDeleteAccount = $derived(deleteConfirmation.trim() === "DELETE");

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
</script>

<Sidebar.Provider>
  <AppSidebar session_id={session_id} />
  <main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
    <Sidebar.Trigger class="mb-4" />
    {@render children?.()}

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
          </Card.Content>
        </Card.Root>

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
  </main>
</Sidebar.Provider>
