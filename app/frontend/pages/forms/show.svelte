<script lang="ts">
  import * as Sidebar from "/components/ui/sidebar/index.js";
  import AppSidebar from "/components/customs/app-sidebar.svelte";
  import Input from "/components/ui/input/input.svelte"
  import { Field, FieldLabel, FieldContent } from "/components/ui/field/index";
  import Button from "/components/ui/button/button.svelte"
  import Card from "/components/ui/card/card.svelte"
  import CardContent from "/components/ui/card/card-content.svelte"
  import { forms_path } from "@/routes";

  let { form, session_id } = $props()

  // preview mode and state
  let preview = $state(true)
  let results = $state<Record<string, any>>({})

  // derived: count of required fields that are filled in results
  const requiredCount = $derived(() => {
    const fields = form.form_fields || []
    return fields.filter((f: any) => f.required && results[f.id]).length
  })

  function handleSubmit(e: Event) {
    e.preventDefault()
    const formEl = (e.currentTarget || e.target) as HTMLFormElement
    if (!formEl.checkValidity()) {
      formEl.reportValidity()
      return
    }

    const fd = new FormData(formEl)
    const data: Record<string, any> = {}
    ;(form.form_fields || []).forEach((f: any) => {
      const key = `field_${f.id}`
      const val = fd.get(key)
      if (val === null) {
        data[f.id] = null
      } else {
        const s = String(val)
        if (f.field_type === "number") {
          data[f.id] = s === "" ? null : Number(s)
        } else {
          data[f.id] = s
        }
      }
    })

    results = data
    preview = false
  }

  function goBack() {
    history.back()
  }
</script>

<Sidebar.Provider>
  <AppSidebar session_id={session_id} />
  <main class="h-screen w-screen bg-muted/40 px-4 py-6 md:px-8">
    <Sidebar.Trigger class="mb-4" />
    <section class="flex items-center justify-center h-full w-full p-6">
      <div class="w-full h-full">
        <h1 class="text-2xl font-semibold text-center">{form.name}</h1>
        <p class="text-sm text-center mb-6">{form.description}</p>

    <div class="flex justify-start mb-4">
      <Button href={forms_path()}>← Back to Forms</Button>
    </div>

    {#if (form.form_fields || []).length === 0}
      <div class="flex items-center justify-center">
        <Card class="w-full max-w-md mx-auto text-center">
          <CardContent>
            <div class="py-8">
              <h2 class="text-lg font-semibold mb-2">This form has no fields yet</h2>
              <p class="text-sm text-muted-foreground">Add fields in the editor to collect data from users.</p>
            </div>
          </CardContent>
        </Card>
      </div>
    {:else}
      {#if preview}
        <form onsubmit={handleSubmit}>
          {#each form.form_fields as field (field['id'])}
            <Field class="mb-4">
              <FieldLabel for={`field_${field['id']}`}>{field['label']}{#if field['required']}*{/if}</FieldLabel>
              <FieldContent>
                <Input id={`field_${field['id']}`} name={`field_${field['id']}`} type={field.field_type || 'text'} required={field.required} />
              </FieldContent>
            </Field>
          {/each}

          <Button type="submit">Submit Preview</Button>
        </form>
      {:else}
        <div>
          <h2>Preview Results</h2>
          <pre>{JSON.stringify(results)}</pre>
        </div>
      {/if}
    {/if}
      </div>
    </section>
  </main>
</Sidebar.Provider>
