<script lang="ts">
  import Input from "/components/ui/input/input.svelte"

  const { id, label, type, required, value, name, onChange, inputOnly = false } = $props()

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

{#if inputOnly}
  <Input
    aria-label={label}
    id={name ?? id}
    name={name}
    type={type || 'text'}
    bind:value={currentValue}
    oninput={onInput}
    {required}
  />
{:else}
  <label>
    {label}
    <Input
      aria-label={label}
      id={name ?? id}
      name={name}
      type={type || 'text'}
      bind:value={currentValue}
      oninput={onInput}
      {required}
    />
  </label>
{/if}
