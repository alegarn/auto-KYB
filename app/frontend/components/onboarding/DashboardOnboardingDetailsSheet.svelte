<script lang="ts">
  import { Button } from '/components/ui/button';
  import * as Sheet from '/components/ui/sheet';
  import { getDashboardOnboardingStepContent, getDashboardOnboardingVariantContent } from '@/lib/dashboard-onboarding-content';
  import type { DashboardOnboarding } from '@/types/dashboard-onboarding';

  let {
    onboarding,
    open = $bindable(false)
  }: {
    onboarding: DashboardOnboarding;
    open?: boolean;
  } = $props();

  const variantContent = $derived(getDashboardOnboardingVariantContent(onboarding.variant));
  const stepsWithContent = $derived(
    onboarding.quick_steps.map((step) => ({
      ...step,
      content: getDashboardOnboardingStepContent(step.key)
    }))
  );

  function statusClasses(complete: boolean) {
    return complete
      ? 'bg-emerald-100 text-emerald-700'
      : 'bg-slate-100 text-slate-600';
  }
</script>

<Sheet.Root bind:open>
  <Sheet.Content side="right" class="w-full sm:max-w-xl p-6">
    <Sheet.Header>
      <Sheet.Title>{variantContent.detailsTitle}</Sheet.Title>
      <Sheet.Description>{variantContent.detailsDescription}</Sheet.Description>
    </Sheet.Header>

    <div class="mt-6 space-y-4 overflow-y-auto pr-1">
      {#each stepsWithContent as step}
        <section class="rounded-lg border border-border bg-background p-4">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h3 class="font-medium text-foreground">{step.content.detailsTitle}</h3>
              <p class="mt-1 text-sm text-muted-foreground">{step.content.detailsBody}</p>
            </div>
            <span class={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClasses(step.complete)}`}>
              {step.complete ? 'Complete' : 'Pending'}
            </span>
          </div>

          {#if step.href}
            <div class="mt-4">
              <Button href={step.href} size="sm" variant={step.complete ? 'secondary' : 'default'}>
                {step.content.ctaLabel}
              </Button>
            </div>
          {/if}
        </section>
      {/each}
    </div>
  </Sheet.Content>
</Sheet.Root>