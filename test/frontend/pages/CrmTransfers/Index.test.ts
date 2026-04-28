import { fireEvent, render, screen } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import Index from '../../../../app/frontend/pages/CrmTransfers/Index.svelte';

vi.mock('@/routes', () => ({
  crm_transfers_path: () => '/crm_transfers',
  retry_crm_transfer_path: (transferId: string) => `/crm_transfers/${transferId}/retry`,
  dashboard_path: () => '/dashboard',
}));

describe('CrmTransfers/Index.svelte', () => {
  const emptyProps = {
    transfers: [],
    filters: {},
    filter_options: { statuses: [], providers: [], triggers: [] },
    meta: { page: 1, per_page: 10, total_count: 0 },
    retention_days: 3,
  };

  const populatedProps = {
    ...emptyProps,
    transfers: [
      {
        id: 'transfer_success',
        created_at: '2026-03-19T10:00:00Z',
        provider: 'hubspot',
        status: 'success',
        trigger: 'manual_export',
        attempts_count: 1,
        retryable: false,
        client: { company_name: 'Acme Corp' },
      },
      {
        id: 'transfer_failed',
        created_at: '2026-03-19T11:00:00Z',
        provider: 'salesforce',
        status: 'failed',
        trigger: 'portal_submit',
        attempts_count: 2,
        retryable: true,
        error_message: 'Provider timeout',
        client: { company_name: 'Globex Inc' },
      },
    ],
    meta: { page: 1, per_page: 10, total_count: 2 },
  };

  beforeEach(() => {
    vi.clearAllMocks();
    document.body.innerHTML = '';
  });

  it('renders the page title, description, and empty state', () => {
    render(Index, { props: emptyProps });

    expect(screen.getByText('CRM Transfer History')).toBeInTheDocument();
    expect(screen.getByText('Operational transfer history for the last 3 days. Older records are removed automatically.')).toBeInTheDocument();
    expect(screen.getByText('No CRM transfers in the last 3 days')).toBeInTheDocument();
  });

  it('renders the transfer table headers and row content', () => {
    render(Index, { props: populatedProps });

    expect(screen.getByRole('columnheader', { name: 'Date' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Client' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Provider' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Trigger' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Status' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Attempts' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Details' })).toBeInTheDocument();
    expect(screen.getByRole('columnheader', { name: 'Actions' })).toBeInTheDocument();
    expect(screen.getByText('Acme Corp')).toBeInTheDocument();
    expect(screen.getByText('Hubspot')).toBeInTheDocument();
    expect(screen.getByText('Success')).toBeInTheDocument();
    expect(screen.getByText('Provider timeout')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Retry' })).toBeInTheDocument();
  });

  it('renders the back to dashboard button', () => {
    render(Index, { props: emptyProps });

    const backButton = screen.getByText('Back to dashboard');
    expect(backButton).toBeInTheDocument();
    expect(backButton.closest('a')?.getAttribute('href')).toContain('/dashboard');
  });
});