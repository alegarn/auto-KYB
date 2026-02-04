<script lang="ts">
  import { Form as InertiaForm } from '@inertiajs/svelte';
  import { clients_path } from "@/routes";
  import Button from '@/components/ui/button/button.svelte';

  let { user, errors = [] } = $props();
</script>

<main class="p-6">
  <header class="mb-4">
    <h1 class="text-2xl font-semibold">New client</h1>
    <p class="text-sm text-muted-foreground">{user?.email}</p>
  </header>

  {#if errors.length}
    <div class="mb-4 text-rose-600">
      <ul>
        {#each errors as err}
          <li>{err}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <InertiaForm method="post" action="/clients">
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-medium">Name</label>
        <input name="client[name]" type="text" class="input" />
      </div>
      <div>
        <label class="block text-sm font-medium">Company name</label>
        <input name="client[company_name]" type="text" class="input" />
      </div>
      <div>
        <label class="block text-sm font-medium">Email</label>
        <input name="client[email]" type="email" class="input" />
      </div>
      <div>
        <label class="block text-sm font-medium">Phone</label>
        <input name="client[phone]" type="text" class="input" />
      </div>
    </div>

    <div class="mt-6">
      <Button type="submit" class="btn">Create client</Button>
    </div>
  </InertiaForm>
</main>
