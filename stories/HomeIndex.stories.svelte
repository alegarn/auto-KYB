<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/Home/Index.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Home/Index',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
