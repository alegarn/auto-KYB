<script context="module">
  import { defineMeta } from '@storybook/addon-svelte-csf';
  const { Story } = defineMeta({
    component: '../app/frontend/components/ui/button/button.svelte'
  });
</script>

<script lang="ts">
  import { expect, fn } from 'storybook/test';

  import Button from '../app/frontend/components/ui/button/button.svelte';

  const clickFn = fn();

  type CanvasLike = {
    getByTestId(testId: string): HTMLElement;
  };

  type PlayContext = {
    canvas: CanvasLike;
    userEvent: {
      click(element: Element): Promise<void>;
    };
  };
</script>

<Story name="Primary">
  Primary
</Story>

<Story name="Destructive" args={{ variant: 'destructive' }}>
  Delete
</Story>

<Story name="Sizes">
  <div style="display:flex;gap:8px;align-items:center">
    <Story args={{ size: 'sm' }}>Small</Story>
    <Story args={{ size: 'default' }}>Default</Story>
    <Story args={{ size: 'lg' }}>Large</Story>
  </div>
</Story>

<Story name="Clickable" args={{ 'data-testid': 'btn', onclick: clickFn }} play={async ({ canvas, userEvent }: PlayContext) => {
  const btn = canvas.getByTestId('btn');
  await userEvent.click(btn);
  await expect(clickFn).toHaveBeenCalled();
}}>
  Click me
</Story>