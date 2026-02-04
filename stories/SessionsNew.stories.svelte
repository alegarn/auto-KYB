<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/sessions/new.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Sessions/New',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
