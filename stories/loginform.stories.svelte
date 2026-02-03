<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  const { Story } = defineMeta({
    component: '../app/frontend/pages/sessions/new.svelte'
  });
</script>

<script lang="ts">
  import { expect, fn } from 'storybook/test';
  import Login from '../app/frontend/pages/sessions/new.svelte';

  const submitMock = fn();
</script>

<Story name="Empty Form">
  <Story />
</Story>

<Story name="Filled Form" play={async ({ canvas, userEvent, canvasElement }) => {
  // find inputs by id used in the real page
  const email = canvas.getByLabelText(/username|email/i) || canvas.getByRole('textbox', { name: /username|email/i });
  const password = canvas.getByLabelText(/password/i) || canvas.getByPlaceholderText(/password/i) || canvas.getByRole('textbox', { name: /password/i });

  // listen for native submit on the form and prevent default while counting
  const form = canvasElement.querySelector('form');
  if (form) {
    form.addEventListener('submit', (e) => { e.preventDefault(); submitMock(); });
  }

  await userEvent.type(email, 'test@example.com');
  await userEvent.type(password, 'supersecret');

  const submit = canvas.getByRole('button', { name: /sign in/i });
  await userEvent.click(submit);

  await expect(submitMock).toHaveBeenCalled();
  await expect(email).toHaveValue('test@example.com');
  await expect(password).toHaveValue('supersecret');
}}> 
  <Story />
</Story>