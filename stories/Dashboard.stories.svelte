<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/Dashboard/Dashboard.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Dashboard',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
