<script lang="ts">
  import { Form, page } from "@inertiajs/svelte";
  import Button from "/components/ui/button/button.svelte";
  import logo from "@/assets/quick_kyb_icon.svg";
  import { root_path, sign_in_path } from '@/routes';

  let { email } = $props();
</script>

<section
  class="flex min-h-screen bg-zinc-50 px-4 py-16 md:py-32 dark:bg-transparent"
>
  <div
    class="bg-card m-auto h-fit w-full max-w-sm rounded-[calc(var(--radius)+.125rem)] border p-0.5 shadow-md dark:[--color-muted:var(--color-zinc-900)]"
  >
    <div class="p-8 pb-6">
      <div class="text-center">
        <a href={root_path()} aria-label="go home" class="mx-auto block w-fit">
          <img
            src={logo}
            alt="Logo"
            class="h-8 w-auto rounded-sm"
            width="32"
            height="32"
          />
        </a>
        <h1 class="mb-1 mt-4 text-xl font-semibold">Payment successful!</h1>
        <p class="text-sm">Your account has been created. Choose how you'd like to sign in.</p>
      </div>

      {#if $page?.flash?.notice}
        <div
          class="mt-4 rounded-(--radius) bg-green-50 p-3 text-sm text-green-700"
          role="status"
        >
          {$page.flash.notice}
        </div>
      {/if}

      <hr class="my-6 border-dashed" />

      <Form action={sign_in_path()} method="post" class="space-y-4">
        {#snippet children({ processing }: { errors: Record<string, string>, processing: boolean })}
          <input type="hidden" name="email" value={email} />
          <Button class="w-full" type="submit" disabled={processing}>
            {processing ? 'Sending…' : 'Email me a sign-in link'}
          </Button>
        {/snippet}
      </Form>

      <p class="mt-4 text-center text-xs text-muted-foreground">
        We'll send a sign-in link to <strong>{email}</strong>.
        You can link a Google account from your settings after signing in.
      </p>
    </div>
  </div>
</section>
