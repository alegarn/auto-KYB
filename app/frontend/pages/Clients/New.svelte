<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import { Form as InertiaForm } from '@inertiajs/svelte';
  import Button from '/components/ui/button/button.svelte';
  import Input from '/components/ui/input/input.svelte';
  import { Label } from '/components/ui/label/index.js';

  let { user, errors = {}, session_id, forms = [] } = $props();

  const hasError = (field: string) => {
    if (!errors) return false;
    if (Array.isArray(errors)) return false;
    return (errors[field] && errors[field].length) || false;
  };
</script>

<Sidebar.Provider>
  <AppSidebar session_id={session_id} />
  <main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
    <Sidebar.Trigger class="mb-4" />
    <section class="p-6 max-w-3xl mx-auto">
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
    <div class="space-y-4 max-w-2xl">
      <div>
        <Label for="client-form" class="block text-sm font-medium">Form to link</Label>
        <select
          id="client-form"
          name="client_form[form_id]"
          class={`w-full border rounded px-3 py-2 bg-background ${hasError('form_id') ? 'border-rose-600' : ''}`}
          required={forms && forms.length > 0}
          disabled={!forms || forms.length === 0}
        >
          <option value="">Select a form</option>
          {#each forms as form}
            <option value={form.id}>{form.name}</option>
          {/each}
        </select>
        {#if hasError('form_id')}
          <div class="text-rose-600 text-sm mt-1">{errors['form_id']?.[0]}</div>
        {/if}
        {#if !forms || forms.length === 0}
          <p class="text-sm text-muted-foreground mt-1">No forms available yet. Create a form first to enable subspace access.</p>
        {/if}
      </div>

      <div>
        <Label for="client-name" class="block text-sm font-medium">Name</Label>
        <Input id="client-name" name="client[name]" class={`w-full ${hasError('name') ? 'border-rose-600' : ''}`} />
        {#if hasError('name')}
          <div class="text-rose-600 text-sm mt-1">{errors['name']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-company" class="block text-sm font-medium">Company name</Label>
        <Input id="client-company" name="client[company_name]" class={`w-full ${hasError('company_name') ? 'border-rose-600' : ''}`} />
        {#if hasError('company_name')}
          <div class="text-rose-600 text-sm mt-1">{errors['company_name']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-email" class="block text-sm font-medium">Email</Label>
        <Input id="client-email" name="client[email]" type="email" class={`w-full ${hasError('email') ? 'border-rose-600' : ''}`} />
        {#if hasError('email')}
          <div class="text-rose-600 text-sm mt-1">{errors['email']?.[0]}</div>
        {/if}
      </div>

      <div>
        <Label for="client-phone" class="block text-sm font-medium">Phone</Label>
        <Input id="client-phone" name="client[phone]" class={`w-full ${hasError('phone') ? 'border-rose-600' : ''}`} />
        {#if hasError('phone')}
          <div class="text-rose-600 text-sm mt-1">{errors['phone']?.[0]}</div>
        {/if}
      </div>

      <fieldset class="mt-4 border p-3 rounded">
        <legend class="text-sm font-medium">Address (optional)</legend>
        <div class="grid grid-cols-1 gap-3 md:grid-cols-2 mt-2">
          <div>
            <Label for="client-street" class="block text-sm">Street</Label>
            <Input id="client-street" name="client[address][street]" />
          </div>
          <div>
            <Label for="client-city" class="block text-sm">City</Label>
            <Input id="client-city" name="client[address][city]" />
          </div>
          <div>
            <Label for="client-postal" class="block text-sm">Postal code</Label>
            <Input id="client-postal" name="client[address][postal_code]" />
          </div>
          <div>
            <Label for="client-country" class="block text-sm">Country</Label>
            <Input id="client-country" name="client[address][country]" />
          </div>
        </div>
      </fieldset>
    </div>

    <div class="mt-6 flex gap-2 items-center">
      <Button type="submit" class="btn">Create client</Button>
      <Button href="/clients" class="btn btn-ghost">Cancel</Button>
    </div>
  </InertiaForm>
    </section>
  </main>
</Sidebar.Provider>
