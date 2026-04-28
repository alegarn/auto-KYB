import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fireEvent, render } from '@testing-library/svelte';
import { router } from '@inertiajs/svelte';
import CrmTransfersIndex from '@/pages/CrmTransfers/Index.svelte';

vi.mock('@/routes', () => ({
  crm_transfers_path: () => '/crm_transfers',
  retry_crm_transfer_path: (transferId: string) => `/crm_transfers/${transferId}/retry`,
  dashboard_path: () => '/dashboard',
}));

describe('CrmTransfers/Index', () => {
  const defaultProps = {
    transfers: [],
    filters: { status: '', provider: '', trigger: '' },
    filter_options: {
      statuses: ['pending', 'processing', 'success', 'failed'],
      providers: ['hubspot', 'salesforce', 'zoho'],
      triggers: ['manual_export', 'portal_submit', 'client_create_sync', 'data_import'],
    },
    meta: {
      page: 1,
      per_page: 10,
      total_count: 0,
    },
    retention_days: 3,
  };

  beforeEach(() => {
    vi.mocked(router.get).mockReset();
    vi.mocked(router.post).mockReset();
  });

  it('renders the default empty state when there are no transfers in the retention window', () => {
    const { getByText } = render(CrmTransfersIndex, { props: defaultProps });

    expect(getByText('No CRM transfers in the last 3 days')).toBeInTheDocument();
  });

  it('renders the filtered empty state when filters are active', () => {
    const { getByText } = render(CrmTransfersIndex, {
      props: {
        ...defaultProps,
        filters: { status: 'failed', provider: '', trigger: '' },
      },
    });

    expect(getByText('No transfers match the current filters')).toBeInTheDocument();
  });

  it('submits filters through Inertia query state', async () => {
    const { getByLabelText, getByText } = render(CrmTransfersIndex, { props: defaultProps });

    await fireEvent.change(getByLabelText('Provider'), { target: { value: 'hubspot' } });
    await fireEvent.click(getByText('Apply filters'));

    expect(router.get).toHaveBeenCalledWith(
      '/crm_transfers',
      { page: 1, provider: 'hubspot' },
      expect.objectContaining({ preserveState: true, preserveScroll: true, replace: true })
    );
  });

  it('renders pending and processing states distinctly', () => {
    const { getByText } = render(CrmTransfersIndex, {
      props: {
        ...defaultProps,
        transfers: [
          {
            id: 'transfer_pending',
            created_at: '2026-03-19T10:00:00Z',
            provider: 'hubspot',
            status: 'pending',
            trigger: 'manual_export',
            attempts_count: 0,
            retryable: false,
            client: { company_name: 'Acme' },
          },
          {
            id: 'transfer_processing',
            created_at: '2026-03-19T11:00:00Z',
            provider: 'salesforce',
            status: 'processing',
            trigger: 'portal_submit',
            attempts_count: 1,
            retryable: false,
            client: { company_name: 'Globex' },
          },
        ],
        meta: {
          page: 1,
          per_page: 10,
          total_count: 2,
        },
      },
    });

    expect(getByText('Queued', { selector: 'span' })).toBeInTheDocument();
    expect(getByText('Processing', { selector: 'span' })).toBeInTheDocument();
  });

  it('renders retry for retryable failed transfers and posts back through Inertia', async () => {
    const { getByText } = render(CrmTransfersIndex, {
      props: {
        ...defaultProps,
        transfers: [
          {
            id: 'transfer_failed',
            created_at: '2026-03-19T12:00:00Z',
            provider: 'hubspot',
            status: 'failed',
            trigger: 'manual_export',
            attempts_count: 1,
            retryable: true,
            error_message: 'Provider timeout',
            client: { company_name: 'Acme' },
          },
        ],
        meta: {
          page: 1,
          per_page: 10,
          total_count: 1,
        },
      },
    });

    await fireEvent.click(getByText('Retry'));

    expect(router.post).toHaveBeenCalledWith(
      '/crm_transfers/transfer_failed/retry',
      { page: 1, status: '', provider: '', trigger: '' },
      expect.objectContaining({ preserveScroll: true, onFinish: expect.any(Function) })
    );
  });
});