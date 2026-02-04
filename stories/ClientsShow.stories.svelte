<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/Clients/Show.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Clients/Show',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
