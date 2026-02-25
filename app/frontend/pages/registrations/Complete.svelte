<script lang="ts">
  import { Form, page } from "@inertiajs/svelte";
  import Button from "/components/ui/button/button.svelte";
  import logo from "@/assets/quick_kyb_icon.svg";

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
        <a href="/" aria-label="go home" class="mx-auto block w-fit">
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

      <Form action="/sign_in" method="post" class="space-y-4">
        {#snippet children({ processing }: { errors: Record<string, string>, processing: boolean })}
          <input type="hidden" name="email" value={email} />
          <Button class="w-full" type="submit" disabled={processing}>
            {processing ? 'Sending…' : 'Email me a sign-in link'}
          </Button>
        {/snippet}
      </Form>

      <div class="my-6 grid grid-cols-[1fr_auto_1fr] items-center gap-3">
        <hr class="border-dashed" />
        <span class="text-muted-foreground text-xs">Or continue with</span>
        <hr class="border-dashed" />
      </div>

      <a
        href="/auth/google_oauth2"
        data-turbo="false"
        class="focus-visible:border-ring focus-visible:ring-ring/50 inline-flex w-full items-center justify-center gap-2 rounded-md border bg-background px-4 py-2 text-sm font-medium shadow-xs transition-all hover:bg-accent hover:text-accent-foreground focus-visible:ring-[3px] disabled:pointer-events-none disabled:opacity-50"
      >
        <svg xmlns="http://www.w3.org/2000/svg" width="0.98em" height="1em" viewBox="0 0 256 262">
          <path fill="#4285f4" d="M255.878 133.451c0-10.734-.871-18.567-2.756-26.69H130.55v48.448h71.947c-1.45 12.04-9.283 30.172-26.69 42.356l-.244 1.622l38.755 30.023l2.685.268c24.659-22.774 38.875-56.282 38.875-96.027"></path>
          <path fill="#34a853" d="M130.55 261.1c35.248 0 64.839-11.605 86.453-31.622l-41.196-31.913c-11.024 7.688-25.82 13.055-45.257 13.055c-34.523 0-63.824-22.773-74.269-54.25l-1.531.13l-40.298 31.187l-.527 1.465C35.393 231.798 79.49 261.1 130.55 261.1"></path>
          <path fill="#fbbc05" d="M56.281 156.37c-2.756-8.123-4.351-16.827-4.351-25.82c0-8.994 1.595-17.697 4.206-25.82l-.073-1.73L15.26 71.312l-1.335.635C5.077 89.644 0 109.517 0 130.55s5.077 40.905 13.925 58.602z"></path>
          <path fill="#eb4335" d="M130.55 50.479c24.514 0 41.05 10.589 50.479 19.438l36.844-35.974C195.245 12.91 165.798 0 130.55 0C79.49 0 35.393 29.301 13.925 71.947l42.211 32.783c10.59-31.477 39.891-54.251 74.414-54.251"></path>
        </svg>
        <span>Sign in with Google</span>
      </a>
    </div>
  </div>
</section>
