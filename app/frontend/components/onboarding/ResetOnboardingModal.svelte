<script lang="ts">
  import { router } from '@inertiajs/svelte';
  import Modal from '/components/ui/modal.svelte';
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
        resetProgress = true;
      }
    });
  }
</script>

<Modal
  bind:showModal={open}
  title="Reset Onboarding Guide"
  description="Are you sure you want to restart the onboarding guide? Your existing forms and clients will NOT be deleted."
  confirmText="Reset Guide"
  confirmTone="default"
  confirmDisabled={isSubmitting}
  onConfirm={handleSubmit}
  onClose={() => open = false}
>
  <div class="py-4 space-y-4">
    <div class="flex items-center space-x-2">
      <Checkbox id="resetProgress" bind:checked={resetProgress} />
      <Label for="resetProgress" class="font-normal cursor-pointer leading-tight relative top-[1px]">
        Also reset the completion status of each step (Form created, Client invited, etc.)
      </Label>
    </div>
  </div>
</Modal>
