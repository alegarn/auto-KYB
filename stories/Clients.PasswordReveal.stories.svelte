<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import PasswordReveal from '../app/frontend/pages/Clients/PasswordReveal.svelte';

  const { Story } = defineMeta({
    title: 'Clients/PasswordReveal',
    component: PasswordReveal,
    tags: ['autodocs'],
    args: {
      access_url: 'https://example.com/client_portal/login/tok-123',
      password: 'one-time-pass'
    }
  });
</script>

<Story name="Default" />
