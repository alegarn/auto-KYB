<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/Clients/Edit.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Clients/Edit',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
