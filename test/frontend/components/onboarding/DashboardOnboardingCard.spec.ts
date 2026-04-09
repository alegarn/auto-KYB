import { cleanup, render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, expect, test, vi } from 'vitest';

import '../../mocks/inertia';
import { router } from '@inertiajs/svelte';
import DashboardOnboardingCard from '../../../../app/frontend/components/onboarding/DashboardOnboardingCard.svelte';
import type { DashboardOnboarding } from '../../../../app/frontend/types/dashboard-onboarding';

const basicOnboarding: DashboardOnboarding = {
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
    { key: 'invite', complete: false, href: '/clients/new' }
  ]
};

const proOnboarding: DashboardOnboarding = {
  ...basicOnboarding,
  variant: 'pro',
  progress_percent: 25,
  completion_rule: 'pro_with_crm',
  quick_steps: [
    ...basicOnboarding.quick_steps,
    { key: 'crm', complete: false, href: '/settings' }
  ]
};

beforeEach(() => {
  vi.clearAllMocks();
  document.body.innerHTML = '';
});

afterEach(() => {
  cleanup();
});

test('renders the basic quick steps correctly', () => {
  render(DashboardOnboardingCard, { props: { onboarding: basicOnboarding } });

  expect(screen.getByText('Review or create a new form')).toBeInTheDocument();
  expect(screen.getByText('Add a client')).toBeInTheDocument();
  expect(screen.getByText('Share secure access')).toBeInTheDocument();
  expect(screen.queryByText('Connect your CRM')).not.toBeInTheDocument();
});

test('includes the CRM quick step for pro onboarding', () => {
  render(DashboardOnboardingCard, { props: { onboarding: proOnboarding } });

  expect(screen.getByText('Connect your CRM')).toBeInTheDocument();
});

test('dismiss submits correctly and hides the card', async () => {
  const user = userEvent.setup();

  render(DashboardOnboardingCard, { props: { onboarding: basicOnboarding } });

  await user.click(screen.getByRole('button', { name: 'Dismiss' }));

  expect((router as any).patch).toHaveBeenCalledWith(
    '/onboarding/dismiss',
    {},
    expect.objectContaining({ preserveScroll: true, preserveState: true })
  );
  expect(screen.queryByText('Launch your first client workflow')).not.toBeInTheDocument();
});

test('opens the detailed sheet and marks details as seen once', async () => {
  const user = userEvent.setup();

  render(DashboardOnboardingCard, { props: { onboarding: basicOnboarding } });

  await user.click(screen.getByRole('button', { name: 'Open detailed onboarding' }));

  expect((router as any).patch).toHaveBeenCalledWith(
    '/onboarding/details_seen',
    {},
    expect.objectContaining({ preserveScroll: true, preserveState: true })
  );
  expect(screen.getByText('Detailed onboarding')).toBeInTheDocument();
});