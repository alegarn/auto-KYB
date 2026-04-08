<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import { Button } from '/components/ui/button';
  import * as Dialog from '/components/ui/dialog';
  import { Label } from '/components/ui/label';
  import { Checkbox } from '/components/ui/checkbox';

  let { open = $bindable(false) } = $props();
  
  let resetProgress = $state(true);
  let isSubmitting = $state(false);

  function handleSubmit() {
    isSubmitting = true;
    router.patch('/onboarding/reset', { reset_progress: resetProgress }, {
      preserveScroll: true,
      preserveState: true,
      onFinish: () => {
        isSubmitting = false;
        open = false;
        resetProgress = false;
      }
    });
  }
</script>

<Dialog.Root bind:open>
  <Dialog.Content>
    <Dialog.Header>
      <Dialog.Title>Reset Onboarding Guide</Dialog.Title>
      <Dialog.Description>
        Are you sure you want to restart the onboarding guide? Your existing forms and clients will NOT be deleted.
      </Dialog.Description>
    </Dialog.Header>
    <div class="py-4 space-y-4">
      <div class="flex items-center space-x-2">
        <Checkbox id="resetProgress" bind:checked={resetProgress} />
        <Label for="resetProgress" class="font-normal cursor-pointer leading-tight relative top-[1px]">
          Also reset the completion status of each step (Form created, Client invited, etc.)
        </Label>
      </div>
    </div>
    <Dialog.Footer>
      <Button variant="outline" onclick={() => open = false} disabled={isSubmitting}>Cancel</Button>
      <Button onclick={handleSubmit} disabled={isSubmitting}>Reset Guide</Button>
    </Dialog.Footer>
  </Dialog.Content>
</Dialog.Root>
