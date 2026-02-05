<script lang="ts">
  const { id, label, type, required, value, name, onChange } = $props()


  let currentValue = $derived(value ?? '')
  $effect(() => {
    currentValue = value ?? ''
  })
  function onInput(e: Event) {
    const target = e.target as HTMLInputElement
    currentValue = target.value
    onChange?.({ id, value: currentValue })
  }

</script>

<label>
  {label}
  {#if type === 'number'}
    <input aria-label={label} type="number" name={name} value={currentValue} oninput={onInput} {required} />
  {:else if type === 'date'}
    <input aria-label={label} type="date" name={name} value={currentValue} oninput={onInput} {required} />
  {:else}
    <input aria-label={label} type="text" name={name} value={currentValue} oninput={onInput} {required} />
  {/if}
</label>
