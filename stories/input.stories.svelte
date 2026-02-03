<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  const { Story } = defineMeta({
    component: '../app/frontend/components/ui/input/input.svelte'
  });
</script>

<script lang="ts">
  import { expect, fn } from 'storybook/test';
  import Input from '../app/frontend/components/ui/input/input.svelte';

  const changeFn = fn();
</script>

<Story name="Empty">
  <Story args={{ 'data-testid': 'input-empty', value: '' }} />
</Story>

<Story name="WithValue">
  <Story args={{ 'data-testid': 'input-with', value: 'hello@example.com' }} />
</Story>

<Story name="Typing" args={{ 'data-testid': 'input-typing' }} play={async ({ canvas, userEvent }) => {
  const input = canvas.getByTestId('input-typing') as HTMLInputElement;
  await userEvent.type(input, 'user@example.com');
  await expect(input).toHaveValue('user@example.com');
}}> 
  <!-- render default story instance -->
  <Story />
</Story>