<script lang="ts">
  import { Form as InertiaForm } from '@inertiajs/svelte';
  import { clients_path } from "@/routes";
  import Button from '@/components/ui/button/button.svelte';

  let { user, errors = {} } = $props();

  const hasError = (field: string) => {
    if (!errors) return false;
    // errors may be an Array (global) or an Object with arrays per field
    if (Array.isArray(errors)) return false;
    return (errors[field] && errors[field].length) || false;
  };
</script>

<main class="p-6">
  <header class="mb-4">
    <h1 class="text-2xl font-semibold">New client</h1>
    <p class="text-sm text-muted-foreground">{user?.email}</p>
  </header>

  {#if Array.isArray(errors) && errors.length}
    <div class="mb-4 text-rose-600">
      <ul>
        {#each errors as err}
          <li>{err}</li>
        {/each}
      </ul>
    </div>
  {/if}

  {#if !Array.isArray(errors) && Object.keys(errors || {}).length}
    <div class="mb-4 text-rose-600">
      <ul>
        {#each Object.entries(errors) as [field, msgs]}
          {#each msgs as msg}
            <li>{field}: {msg}</li>
          {/each}
        {/each}
      </ul>
    </div>
  {/if}

  <InertiaForm method="post" action="/clients">
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-medium">Name</label>
        <input name="client[name]" type="text" class={`input ${hasError('name') ? 'border-rose-600' : ''}`} />
        {#if hasError('name')}
          <div class="text-rose-600 text-sm mt-1">{errors['name']?.[0]}</div>
        {/if}
      </div>

      <div>
        <label class="block text-sm font-medium">Company name</label>
        <input name="client[company_name]" type="text" class={`input ${hasError('company_name') ? 'border-rose-600' : ''}`} />
        {#if hasError('company_name')}
          <div class="text-rose-600 text-sm mt-1">{errors['company_name']?.[0]}</div>
        {/if}
      </div>

      <div>
        <label class="block text-sm font-medium">Email</label>
        <input name="client[email]" type="email" class={`input ${hasError('email') ? 'border-rose-600' : ''}`} />
        {#if hasError('email')}
          <div class="text-rose-600 text-sm mt-1">{errors['email']?.[0]}</div>
        {/if}
      </div>

      <div>
        <label class="block text-sm font-medium">Phone</label>
        <input name="client[phone]" type="text" class={`input ${hasError('phone') ? 'border-rose-600' : ''}`} />
        {#if hasError('phone')}
          <div class="text-rose-600 text-sm mt-1">{errors['phone']?.[0]}</div>
        {/if}
      </div>

      <fieldset class="mt-4 border p-3 rounded">
        <legend class="text-sm font-medium">Address (optional)</legend>
        <div class="grid grid-cols-1 gap-3 md:grid-cols-2 mt-2">
          <div>
            <label class="block text-sm">Street</label>
            <input name="client[address][street]" type="text" class="input" />
          </div>
          <div>
            <label class="block text-sm">City</label>
            <input name="client[address][city]" type="text" class="input" />
          </div>
          <div>
            <label class="block text-sm">Postal code</label>
            <input name="client[address][postal_code]" type="text" class="input" />
          </div>
          <div>
            <label class="block text-sm">Country</label>
            <input name="client[address][country]" type="text" class="input" />
          </div>
        </div>
      </fieldset>
    </div>

    <div class="mt-6 flex gap-2 items-center">
      <Button type="submit" class="btn">Create client</Button>
      <a href="/clients" class="btn btn-ghost">Cancel</a>
    </div>
  </InertiaForm>
</main>
