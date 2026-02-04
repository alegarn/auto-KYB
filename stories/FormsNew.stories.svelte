<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/forms/new.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Forms/New',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
