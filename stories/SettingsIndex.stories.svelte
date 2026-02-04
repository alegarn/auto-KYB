<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/Settings/Index.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Settings/Index',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
