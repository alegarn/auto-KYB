<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/inertia_example/index.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Inertia Example',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
