<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "/components/ui/button/button.svelte";
  import Input from "/components/ui/input/input.svelte";
  import Label from "/components/ui/label/label.svelte";
  import { root_path, sign_in_path, sign_up_path } from "@/routes";
  import { page } from "@inertiajs/svelte";
  import logo from "@/assets/quick_kyb_icon.svg";
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
    action={sign_up_path()}
    method="post"
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
          Create a Quick KYB Account
        </h1>
        <p class="text-sm">Welcome! Create an account to get started</p>
      </div>

      <div class="mt-6 grid grid-cols-1 gap-3">
        <a href="/auth/google_oauth2" data-turbo="false" class="w-full focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-all outline-none focus-visible:ring-[3px] disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 bg-background selection:bg-primary selection:text-primary-foreground ring-offset-background hover:bg-accent hover:text-accent-foreground dark:bg-input/30 dark:border-input dark:hover:bg-input/50 border shadow-xs h-9 px-4 py-2 has-[>svg]:px-3 justify-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="0.98em"
            height="1em"
            viewBox="0 0 256 262"
          >
            <path
              fill="#4285f4"
              d="M255.878 133.451c0-10.734-.871-18.567-2.756-26.69H130.55v48.448h71.947c-1.45 12.04-9.283 30.172-26.69 42.356l-.244 1.622l38.755 30.023l2.685.268c24.659-22.774 38.875-56.282 38.875-96.027"
            ></path>
            <path
              fill="#34a853"
              d="M130.55 261.1c35.248 0 64.839-11.605 86.453-31.622l-41.196-31.913c-11.024 7.688-25.82 13.055-45.257 13.055c-34.523 0-63.824-22.773-74.269-54.25l-1.531.13l-40.298 31.187l-.527 1.465C35.393 231.798 79.49 261.1 130.55 261.1"
            ></path>
            <path
              fill="#fbbc05"
              d="M56.281 156.37c-2.756-8.123-4.351-16.827-4.351-25.82c0-8.994 1.595-17.697 4.206-25.82l-.073-1.73L15.26 71.312l-1.335.635C5.077 89.644 0 109.517 0 130.55s5.077 40.905 13.925 58.602z"
            ></path>
            <path
              fill="#eb4335"
              d="M130.55 50.479c24.514 0 41.05 10.589 50.479 19.438l36.844-35.974C195.245 12.91 165.798 0 130.55 0C79.49 0 35.393 29.301 13.925 71.947l42.211 32.783c10.59-31.477 39.891-54.251 74.414-54.251"
            ></path>
          </svg>
          <span>Sign up with Google</span>
        </a>
      </div>

      <hr class="my-4 border-dashed" />

      <div class="space-y-5">
        <div class="space-y-2">
          <Label for="email" class="block text-sm">Email</Label>
          <Input type="email" required name="email" id="email" />
          {#if errors.email}
            <p class="text-sm text-red-500">{errors.email}</p>
          {/if}
        </div>

        <Button class="w-full" type="submit" disabled={processing}>
          {processing ? 'Creating...' : 'Create account'}
        </Button>
      </div>
    </div>

    <div class="bg-muted rounded-(--radius) border p-3">
      <p class="text-accent-foreground text-center text-sm">
        Have an account ?
        <Button href={sign_in_path()} variant="link" class="px-2">Sign in</Button>
      </p>
    </div>
    {/snippet}
  </Form>
</section>
