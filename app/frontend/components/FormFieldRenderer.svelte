<script lang="ts">
  import { createEventDispatcher } from 'svelte'
  export let field: { id: string; label: string; type: string; value: any }

  const dispatch = createEventDispatcher()

  let value = field.value ?? ''

  function onInput(e: Event) {
    const target = e.target as HTMLInputElement
    value = target.value
    dispatch('change', { id: field.id, value })
  }
</script>

<label>
  {field.label}
  {#if field.type === 'number'}
    <input aria-label={field.label} type="number" value={value} on:input={onInput} />
  {:else if field.type === 'date'}
    <input aria-label={field.label} type="date" value={value} on:input={onInput} />
  {:else}
    <input aria-label={field.label} type="text" value={value} on:input={onInput} />
  {/if}
</label>
