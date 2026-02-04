<script lang="ts">
  export let field: { id: string; label: string; type: string; value: any }
  export let name: string | undefined = undefined

  // Use a callback prop instead of the deprecated createEventDispatcher
  export let onChange: ((detail: { id: string; value: any }) => void) | undefined = undefined

  let value = field.value ?? ''
  function onInput(e: Event) {
    const target = e.target as HTMLInputElement
    value = target.value
    onChange?.({ id: field.id, value })
  }

</script>

<label>
  {field.label}
  {#if field.type === 'number'}
    <input aria-label={field.label} type="number" name={name} value={value} on:input={onInput} />
  {:else if field.type === 'date'}
    <input aria-label={field.label} type="date" name={name} value={value} on:input={onInput} />
  {:else}
    <input aria-label={field.label} type="text" name={name} value={value} on:input={onInput} />
  {/if}
</label>
