<script lang="ts">
  import FormFieldRenderer from "@/components/customs/FormFieldRenderer.svelte"
  import { isLayoutField, type FormSettings } from "@/components/customs/form-builder/types"
  import { Field, FieldLabel, FieldContent } from "@/components/ui/field/index";
  import Button from "/components/ui/button/button.svelte"
  import Card from "/components/ui/card/card.svelte"
  import CardContent from "/components/ui/card/card-content.svelte"
  import { forms_path } from "@/routes";

  let { form } = $props()

  // preview mode and state
  let preview = $state(true)
  let results = $state<Record<string, any>>({})

  // output format for preview results: 'json' or 'csv'
  let outputFormat = $state('json')

  // form settings for styling
  const formSettings = $derived<FormSettings>(form?.structure?.settings || {})

  // formatted results string (JSON pretty or CSV) - excludes layout fields
  function formattedResults(outputFormat: string, results: Record<string, any>): string {
    try {
      const fields = (form.form_fields || []).filter((f: any) => !isLayoutField(f.field_type))

      if (outputFormat === 'json') {
        const out: Record<string, any> = {}
        fields.forEach((f: any) => {
          const key = f.metadata?.export_key || (f.label != null ? String(f.label) : String(f.id))
          const val = results[f.id]
          out[key] = val === undefined ? null : val
        })
        return JSON.stringify(out, null, 2)
      }

      // build CSV: header + rows for each form field (label,value)
      const rows: string[][] = [["label", "value"]]
      fields.forEach((f: any) => {
        const val = results[f.id]
        let s = val === null || val === undefined ? '' : String(val)
        if (s.includes('"') || s.includes(',') || s.includes('\n')) {
          s = '"' + s.replace(/"/g, '""') + '"'
        }
        const key = f.metadata?.export_key || String(f.label)
        rows.push([key, s])
      })
      return rows.map(r => r.join(',')).join('\n')
    } catch (e) {
      return String(results)
    }
  }

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
    const data: Record<string, any> = {};
    (form.form_fields || []).forEach((f: any) => {
      if (isLayoutField(f.field_type)) return;
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
        <div
          class="rounded-lg border shadow-sm overflow-hidden"
          style:background-color={formSettings.form_background_color || '#ffffff'}
        >
          {#if formSettings.header_background_color}
            <div class="px-6 py-4" style:background-color={formSettings.header_background_color}>
              <h2 class="text-lg font-semibold">{form.name}</h2>
            </div>
          {/if}
          <form onsubmit={handleSubmit} class="p-6">
            {#each form.form_fields as field (field['id'] ?? field['position'])}
              {#if isLayoutField(field.field_type)}
                <FormFieldRenderer
                  id={field['id'] ?? `field_${field['position']}`}
                  label={field['label']}
                  type={field.field_type || 'text'}
                  required={false}
                  inputOnly={true}
                  metadata={field.metadata}
                />
              {:else}
                <Field class="mb-4">
                  <FieldLabel for={`field_${field['id']}`}>{field['label']}{#if field['required']}*{/if}</FieldLabel>
                  <FieldContent>
                    <FormFieldRenderer
                      id={`field_${field['id']}`}
                      label={field['label']}
                      type={field.field_type || 'text'}
                      required={field.required}
                      name={`field_${field['id']}`}
                      value={''}
                      inputOnly={true}
                      onChange={()=>{}}
                      metadata={field.metadata}
                    />
                  </FieldContent>
                </Field>
              {/if}
            {/each}

            <button
              type="submit"
              class="mt-4 rounded-md px-4 py-2 text-sm font-medium text-white transition-colors hover:opacity-90"
              style:background-color={formSettings.primary_color || '#2563eb'}
            >
              Submit Preview
            </button>
          </form>
        </div>
      {:else}
        <div>
          <h2>Preview Results</h2>
          <div class="flex items-center gap-2 mb-2">
            <button type="button" class="px-3 py-1 rounded bg-gray-100" onclick={() => (outputFormat = 'json')}>JSON</button>
            <button type="button" class="px-3 py-1 rounded bg-gray-100" onclick={() => (outputFormat = 'csv')}>CSV</button>
            <div class="text-sm text-muted-foreground ml-2">Format: {outputFormat}</div>
          </div>
          <pre class="whitespace-pre-wrap break-words max-w-full overflow-auto">{formattedResults(outputFormat, results)}</pre>
        </div>
      {/if}
    {/if}
      </div>
</section>
