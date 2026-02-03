<script lang="ts">
  import { createEventDispatcher } from 'svelte'
  import DropdownMenu from '/components/ui/dropdown-menu/dropdown-menu.svelte'
  import DropdownMenuTrigger from '/components/ui/dropdown-menu/dropdown-menu-trigger.svelte'
  import DropdownMenuContent from '/components/ui/dropdown-menu/dropdown-menu-content.svelte'
  import DropdownMenuGroup from '/components/ui/dropdown-menu/dropdown-menu-group.svelte'
  import DropdownMenuRadioGroup from '/components/ui/dropdown-menu/dropdown-menu-radio-group.svelte'
  import DropdownMenuRadioItem from '/components/ui/dropdown-menu/dropdown-menu-radio-item.svelte'
  import Button from '/components/ui/button/button.svelte'

  export let value: string = ''
  export let items: Array<{ value: string; label: string }> = []

  const dispatch = createEventDispatcher()

  function select(v: string) {
    dispatch('select', { value: v })
  }
</script>

<DropdownMenu>
  <DropdownMenuTrigger>
    <slot name="trigger" {value}>
      <Button variant="outline">{value}</Button>
    </slot>
  </DropdownMenuTrigger>

  <DropdownMenuContent>
    <DropdownMenuGroup>
      <DropdownMenuRadioGroup bind:value={value}>
        {#each items as item}
          <DropdownMenuRadioItem value={item.value} onclick={() => select(item.value)}>{item.label}</DropdownMenuRadioItem>
        {/each}
      </DropdownMenuRadioGroup>
    </DropdownMenuGroup>
  </DropdownMenuContent>
</DropdownMenu>
