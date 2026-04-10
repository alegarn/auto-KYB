<script lang="ts">
  import DashboardOnboardingDetailsSheet from '../../../../app/frontend/components/onboarding/DashboardOnboardingDetailsSheet.svelte';
  import type { DashboardOnboarding } from '../../../../app/frontend/types/dashboard-onboarding';

  let { onboarding }: { onboarding: DashboardOnboarding } = $props();
  let open = $state(true);
</script>

<DashboardOnboardingDetailsSheet bind:open {onboarding} />
<p data-testid="sheet-open-state">{open ? 'open' : 'closed'}</p>