<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import Login from '../app/frontend/pages/ClientPortal/Login.svelte';
  import { fn } from 'storybook/test';

  const { Story } = defineMeta({
    title: 'ClientPortal/Login',
    component: Login,
    tags: ['autodocs'],
    args: {
      access_token: 'tok-abc',
      onLogin: fn()
    }
  });
</script>

<Story name="Default" />
