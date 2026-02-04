<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/forms/edit.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Forms/Edit',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
