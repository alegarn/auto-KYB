<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  import FormResponse from '../app/frontend/pages/ClientPortal/FormResponse.svelte';
  import { fn } from 'storybook/test';

  const sampleForm = {
    id: 'f1',
    name: 'Sample Form',
    form_fields: [
      { id: 'a', label: 'Name', type: 'text', value: '' },
      { id: 'b', label: 'Age', type: 'number', value: null },
      { id: 'c', label: 'Birthday', type: 'date', value: null }
    ]
  };

  const { Story } = defineMeta({
    title: 'ClientPortal/FormResponse',
    component: FormResponse,
    tags: ['autodocs'],
    args: {
      form: sampleForm,
      onSave: fn()
    }
  });
</script>

<Story name="Default" />
