<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import { router } from '@inertiajs/svelte'
  import { Button } from "/components/ui/button/index.js"
  import { Input } from "/components/ui/input/index.js"
  import { Label } from "/components/ui/label/index.js"
  import FormBuilder from "/components/customs/FormBuilder.svelte"
  import type { FormField } from "/components/customs/form-builder/types"
  import { forms_path } from '@/routes';

  const { errors: serverErrors, session_id } = $props()

  let name = $state("")
  let fields = $state<FormField[]>([])
  let clientError = $state("")
  let submitting = $state(false)

  function handleSubmit() {
    clientError = ""
    if (!name.trim()) {
      clientError = "Name is required"
      return
    }

    submitting = true
    router.post(forms_path(), {
      form: {
        name,
        structure: {
          fields: fields.map((f, i) => ({
            label: f.label,
            field_type: f.field_type,
            required: f.required,
            position: i + 1,
            metadata: f.metadata || {},
          })),
        },
      },
    } as any, {
      preserveState: true,
      onFinish: () => { submitting = false },
    })
  }

  function cancel() {
    history.back()
  }
</script>

<Sidebar.Provider>
  <AppSidebar session_id={session_id} />
  <main class="min-h-screen bg-muted/40 px-4 py-6 md:px-8">
    <Sidebar.Trigger class="mb-4" />
    <section class="mx-auto max-w-7xl">
      <div class="mb-6 flex items-center justify-between">
        <h1 class="text-2xl font-semibold">Create Form</h1>
        <div class="flex gap-2">
          <Button type="button" variant="outline" onclick={cancel}>Cancel</Button>
          <Button type="button" onclick={handleSubmit} disabled={submitting}>
            {submitting ? 'Creating...' : 'Create Form'}
          </Button>
        </div>
      </div>

      {#if serverErrors}
        {#if Array.isArray(serverErrors) && serverErrors.length}
          <div class="mb-4 rounded-md border border-destructive/30 bg-destructive/5 px-4 py-3">
            {#each serverErrors as msg}
              <p class="text-sm text-destructive">{msg}</p>
            {/each}
          </div>
        {:else if typeof serverErrors === 'object'}
          {#each Object.values(serverErrors) as msg}
            <p class="mb-4 text-sm text-destructive">{msg}</p>
          {/each}
        {/if}
      {/if}

      {#if clientError}
        <p class="mb-4 text-sm text-destructive">{clientError}</p>
      {/if}

      <div class="mb-6 max-w-md">
        <Label for="form-name" class="mb-1.5 block text-sm font-medium">Form Name</Label>
        <Input id="form-name" bind:value={name} placeholder="Enter form name" />
      </div>

      <FormBuilder bind:fields />
    </section>
  </main>
</Sidebar.Provider>
