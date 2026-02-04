<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/registrations/new.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Registrations/New',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
