import { cleanup, render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
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

afterEach(() => {
  cleanup();
});

test('hides the CRM section for basic onboarding', () => {
  render(DashboardOnboardingDetailsSheetTestHost, { props: { onboarding: basicOnboarding } });

  expect(screen.getByText('Detailed onboarding')).toBeInTheDocument();
  expect(screen.queryByText('Connect your CRM from Settings')).not.toBeInTheDocument();
});

test('shows the CRM section for pro onboarding and closes correctly', async () => {
  const user = userEvent.setup();

  render(DashboardOnboardingDetailsSheetTestHost, { props: { onboarding: proOnboarding } });

  expect(screen.getByText('Connect your CRM from Settings')).toBeInTheDocument();
  expect(screen.getByTestId('sheet-open-state')).toHaveTextContent('open');

  await user.click(screen.getByRole('button', { name: 'Close' }));

  await waitFor(() => {
    expect(screen.getByTestId('sheet-open-state')).toHaveTextContent('closed');
  });
});