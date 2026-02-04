<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/Clients/New.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Clients/New',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
