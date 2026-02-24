<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "/components/ui/button/button.svelte";
  import Input from "/components/ui/input/input.svelte";
  import Label from "/components/ui/label/label.svelte";
  import { root_path, sign_in_path } from "@/routes";
  import { page } from "@inertiajs/svelte";
  import logo from "@/assets/quick_kyb_icon.svg";

  let { email, session_id } = $props();

  function handleSuccess(event: CustomEvent) {
    const detail = event.detail || {};
    const response = detail.props || detail;

    if (response.redirect_url) {
      window.location.href = response.redirect_url;
    }
  }
</script>

{#if $page?.flash?.alert}
  <div
    class="mb-4 rounded-(--radius) bg-red-100 p-4 text-sm text-red-800 dark:bg-red-200"
    role="alert"
  >
    {$page?.flash?.alert}
  </div>
{/if}

<section
  class="flex min-h-screen bg-zinc-50 px-4 py-16 md:py-32 dark:bg-transparent"
>
  <Form
    action="/registrations/finalize"
    method="post"
    onsuccess={handleSuccess}
    class="bg-card m-auto h-fit w-full max-w-sm rounded-[calc(var(--radius)+.125rem)] border p-0.5 shadow-md dark:[--color-muted:var(--color-zinc-900)]"
  >
    {#snippet children({ errors, processing }: { errors: Record<string, string>, processing: boolean })}
      <div class="p-8 pb-6">
        <div>
          <Button href={root_path()} aria-label="go home" variant="ghost">
            <img
              src={logo}
              alt="Logo"
              class="h-8 w-auto rounded-sm"
              width="32"
              height="32"
            />
          </Button>
          <h1 class="text-title mb-1 mt-4 text-xl font-semibold">
            Complete Registration
          </h1>
          <p class="text-sm">Payment successful! Please set your password to complete your account.</p>
        </div>

        <hr class="my-4 border-dashed" />

        <div class="space-y-5">
          <input type="hidden" name="session_id" value={session_id} />
          
          <div class="space-y-2">
            <Label for="email" class="block text-sm">Email</Label>
            <Input type="email" disabled value={email} id="email" />
          </div>

          <div class="space-y-2">
            <Label for="password" class="block text-sm">Password</Label>
            <Input type="password" required name="password" id="password" />
            {#if errors.password}
              <p class="text-sm text-red-500">{errors.password}</p>
            {/if}
          </div>

          <div class="space-y-2">
            <Label for="password_confirmation" class="block text-sm">Confirm Password</Label>
            <Input type="password" required name="password_confirmation" id="password_confirmation" />
            {#if errors.password_confirmation}
              <p class="text-sm text-red-500">{errors.password_confirmation}</p>
            {/if}
          </div>

          <Button class="w-full" type="submit" disabled={processing}>
            {processing ? 'Completing...' : 'Complete Registration'}
          </Button>
        </div>
      </div>
    {/snippet}
  </Form>
</section>
