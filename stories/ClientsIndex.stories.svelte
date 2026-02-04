<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/Clients/Index.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Clients/Index',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
