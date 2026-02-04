<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Page from '../app/frontend/pages/forms/index.svelte';

  const { Story } = defineMeta({
    title: 'Pages/Forms/Index',
    component: Page,
    tags: ['autodocs'],
  });
</script>

<Story name="Default" />
