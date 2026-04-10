import { describe, expect, test } from 'vitest';

import { getGuidePracticeItems, getOnboardingTutorialKey, withOnboardingTutorial } from '../../../app/frontend/lib/onboarding-tutorials';
import type { DashboardOnboarding, GuidePractice, DashboardOnboardingStep } from '../../../app/frontend/types/dashboard-onboarding';

const onboarding: DashboardOnboarding = {
  visible: true,
  variant: 'basic',
  progress_percent: 33,
  completion_rule: 'basic_core',
  can_dismiss: true,
  detailed_view_seen: false,
  guides_seen: {},
  quick_steps: [
    { key: 'form', complete: true, href: '/forms/123/edit' },
    { key: 'client', complete: false, href: '/clients/new' },
    { key: 'invite', complete: false, href: '/clients/new' },
    { key: 'review', complete: false, href: '/clients' },
  ],
};

describe('onboarding tutorial helpers', () => {
  test('adds the tutorial query param while preserving existing query params', () => {
    expect(withOnboardingTutorial('/clients/42?tab=exports', 'client_exports_basics')).toBe(
      '/clients/42?tab=exports&onboarding_tutorial=client_exports_basics',
    );
  });

  test('extracts a valid tutorial key from the current url', () => {
    expect(getOnboardingTutorialKey('/settings?onboarding_tutorial=crm_sync_basics')).toBe('crm_sync_basics');
    expect(getOnboardingTutorialKey('/settings?onboarding_tutorial=unknown')).toBeNull();
  });

  test('disables client export practice when there is no concrete client page yet', () => {
    const tutorials = getGuidePracticeItems('client_workflow', onboarding);
    const exportTutorial = tutorials.find((tutorial: GuidePractice) => tutorial.tutorialKey === 'client_exports_basics');

    expect(exportTutorial).toMatchObject({
      href: null,
      unavailableReason: 'Create or open a client record first so the export panel exists on the page.',
    });
  });

  test('enables client export practice when the review step points to a client page', () => {
    const tutorials = getGuidePracticeItems('client_workflow', {
      ...onboarding,
      quick_steps: onboarding.quick_steps.map((step: DashboardOnboardingStep) => step.key === 'review'
        ? { ...step, href: '/clients/42' }
        : step),
    });
    const exportTutorial = tutorials.find((tutorial: GuidePractice) => tutorial.tutorialKey === 'client_exports_basics');

    expect(exportTutorial?.href).toBe('/clients/42?onboarding_tutorial=client_exports_basics');
  });
});