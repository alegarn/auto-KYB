import { cleanup, render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { router } from '@inertiajs/svelte';
import { afterEach, beforeEach, expect, test, vi } from 'vitest';

import DashboardOnboardingDetailsSheetTestHost from './DashboardOnboardingDetailsSheetTestHost.svelte';
import type { DashboardOnboarding } from '../../../../app/frontend/types/dashboard-onboarding';

const basicOnboarding: DashboardOnboarding = {
  visible: true,
  variant: 'basic',
  progress_percent: 33,
  completion_rule: 'basic_core',
  can_dismiss: true,
  detailed_view_seen: true,
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

function waitForSheetTeardown() {
  return new Promise((resolve) => {
    window.setTimeout(resolve, 30);
  });
}

afterEach(async () => {
  cleanup();

  await waitForSheetTeardown();
});

async function closeSheet(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByRole('button', { name: 'Close' }));

  await waitFor(() => {
    expect(screen.getByTestId('sheet-open-state')).toHaveTextContent('closed');
  });

  await waitForSheetTeardown();
}

test('hides the CRM section for basic onboarding', async () => {
  const user = userEvent.setup();

  render(DashboardOnboardingDetailsSheetTestHost, { props: { onboarding: basicOnboarding } });

  expect(screen.getByText('Detailed onboarding')).toBeInTheDocument();
  expect(screen.queryByText('Connect your CRM from Settings')).not.toBeInTheDocument();

  await closeSheet(user);
});

test('shows practice tutorials with contextual availability in the Explore tab', async () => {
  const user = userEvent.setup();

  render(DashboardOnboardingDetailsSheetTestHost, { props: { onboarding: basicOnboarding } });

  await user.click(screen.getByRole('button', { name: 'Explore' }));
  await user.click(screen.getByRole('button', { name: /Client Workflow/i }));

  expect(screen.getByText('Practice in the app')).toBeInTheDocument();

  const clientTutorialLink = screen.getByRole('link', { name: 'Open client tutorial' });
  expect(clientTutorialLink).toHaveAttribute('href', expect.stringContaining('/clients/new?onboarding_tutorial=client_profile_basics'));

  const disabledTutorialButton = screen.getByRole('button', { name: 'Unavailable' });
  expect(disabledTutorialButton).toBeDisabled();
  expect(screen.getByText('Create or open a client record first so the export panel exists on the page.')).toBeInTheDocument();

  await closeSheet(user);
});

test('marks a guide as seen when opening it from the Explore tab', async () => {
  const user = userEvent.setup();

  render(DashboardOnboardingDetailsSheetTestHost, { props: { onboarding: basicOnboarding } });

  await user.click(screen.getByRole('button', { name: 'Explore' }));
  await user.click(screen.getByRole('button', { name: /Client Workflow/i }));

  expect(router.patch).toHaveBeenCalledWith(
    '/onboarding/guide_seen',
    { guide_key: 'client_workflow' },
    { preserveScroll: true, preserveState: true },
  );

  await closeSheet(user);
});

test('shows the CRM section for pro onboarding and closes correctly', async () => {
  const user = userEvent.setup();

  render(DashboardOnboardingDetailsSheetTestHost, { props: { onboarding: proOnboarding } });

  expect(screen.getByText('Connect your CRM from Settings')).toBeInTheDocument();
  await user.click(screen.getByRole('button', { name: 'Explore' }));
  await user.click(screen.getByRole('button', { name: /CRM Integration/i }));
  expect(screen.getByRole('link', { name: 'Open CRM tutorial' })).toHaveAttribute('href', expect.stringContaining('/settings?onboarding_tutorial=crm_sync_basics'));
  expect(screen.getByTestId('sheet-open-state')).toHaveTextContent('open');

  await user.click(screen.getByRole('button', { name: 'Close' }));

  await waitFor(() => {
    expect(screen.getByTestId('sheet-open-state')).toHaveTextContent('closed');
  });
});