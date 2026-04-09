<script lang="ts">
  import { Button } from '/components/ui/button';
  import { clearOnboardingTutorialFromCurrentLocation, getOnboardingTutorial } from '@/lib/onboarding-tutorials';
  import type { OnboardingTutorialKey } from '@/types/dashboard-onboarding';

  let { tutorialKey }: { tutorialKey: OnboardingTutorialKey } = $props();

  let stepIndex = $state(0);
  let targetRect = $state<DOMRect | null>(null);
  let targetMissing = $state(false);

  const tutorial = $derived(getOnboardingTutorial(tutorialKey));
  const step = $derived(tutorial.steps[stepIndex]);
  const isLastStep = $derived(stepIndex === tutorial.steps.length - 1);

  function findTarget(): HTMLElement | null {
    if (typeof document === 'undefined') return null;
    return document.querySelector<HTMLElement>(step.target);
  }

  function syncTargetRect() {
    const target = findTarget();

    if (!target) {
      targetRect = null;
      targetMissing = true;
      return;
    }

    targetRect = target.getBoundingClientRect();
    targetMissing = false;
  }

  function bringTargetIntoView() {
    const target = findTarget();
    if (!target) return;

    target.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
    window.setTimeout(syncTargetRect, 180);
  }

  function runStepAction() {
    const target = findTarget();
    if (!target || !step.action) {
      syncTargetRect();
      return;
    }

    if (step.action.kind === 'focus') {
      target.focus();
    } else if (step.action.kind === 'click') {
      target.click();
    } else {
      target.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
    }

    window.setTimeout(syncTargetRect, 180);
  }

  function goBack() {
    if (stepIndex === 0) return;
    stepIndex -= 1;
  }

  function goForward() {
    if (isLastStep) {
      clearOnboardingTutorialFromCurrentLocation();
      return;
    }

    stepIndex += 1;
  }

  $effect(() => {
    stepIndex = 0;
  });

  $effect(() => {
    if (typeof window === 'undefined') return;

    syncTargetRect();
    bringTargetIntoView();

    const handleViewportChange = () => syncTargetRect();
    window.addEventListener('resize', handleViewportChange);
    window.addEventListener('scroll', handleViewportChange, true);

    return () => {
      window.removeEventListener('resize', handleViewportChange);
      window.removeEventListener('scroll', handleViewportChange, true);
    };
  });
</script>

<div class="pointer-events-none fixed inset-0 z-[90]">
  {#if targetRect}
    <div
      class="absolute rounded-2xl border-2 border-primary shadow-[0_0_0_9999px_rgba(15,23,42,0.46)] transition-all duration-200"
      style={`top:${Math.max(targetRect.top - 8, 8)}px;left:${Math.max(targetRect.left - 8, 8)}px;width:${targetRect.width + 16}px;height:${targetRect.height + 16}px;`}
    ></div>
  {:else}
    <div class="absolute inset-0 bg-slate-950/46"></div>
  {/if}

  <aside class="pointer-events-auto absolute bottom-4 right-4 w-[min(28rem,calc(100vw-2rem))] rounded-2xl border bg-background p-5 shadow-2xl">
    <p class="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
      Mini tutorial {stepIndex + 1}/{tutorial.steps.length}
    </p>
    <h2 class="mt-2 text-lg font-semibold text-foreground">{step.title}</h2>
    <p class="mt-2 text-sm text-muted-foreground">{step.body}</p>

    {#if targetMissing}
      <div class="mt-4 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm text-amber-950">
        {step.missingTargetBody ?? 'This control is not visible right now. You can keep the tutorial open, bring the relevant UI into view, and continue when ready.'}
      </div>
    {/if}

    <div class="mt-5 flex flex-wrap gap-2">
      {#if step.action}
        <Button type="button" variant="secondary" onclick={runStepAction}>
          {step.action.label}
        </Button>
      {/if}

      {#if stepIndex > 0}
        <Button type="button" variant="outline" onclick={goBack}>
          Back
        </Button>
      {/if}

      <Button type="button" onclick={goForward}>
        {isLastStep ? 'Finish tutorial' : 'Next'}
      </Button>

      <Button type="button" variant="ghost" onclick={clearOnboardingTutorialFromCurrentLocation}>
        Quit tutorial
      </Button>
    </div>
  </aside>
</div>