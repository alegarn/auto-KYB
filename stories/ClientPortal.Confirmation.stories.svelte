<script>
  import { Meta, Story } from '@storybook/addon-svelte-csf';
  import Confirmation from '../app/frontend/pages/ClientPortal/Confirmation.svelte';

  export let client = { id: 1, name: 'ACME Corp' };
  export let form = { id: 1, name: 'Onboarding Form' };
</script>

<Story name="Default">
  <Confirmation {client} {form} />
</Story>
