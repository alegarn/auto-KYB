<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/forms/show.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Forms/Show',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
