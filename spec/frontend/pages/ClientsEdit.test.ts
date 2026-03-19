import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fireEvent, render, waitFor } from '@testing-library/svelte';
import ClientsEdit from '@/pages/Clients/Edit.svelte';

const mockFetch = vi.fn();
const localStorageState = new Map<string, string>();

Object.defineProperty(window, 'localStorage', {
  configurable: true,
  value: {
    getItem: vi.fn((key: string) => localStorageState.get(key) ?? null),
    setItem: vi.fn((key: string, value: string) => {
      localStorageState.set(key, value);
    }),
    removeItem: vi.fn((key: string) => {
      localStorageState.delete(key);
    }),
    clear: vi.fn(() => {
      localStorageState.clear();
    })
  }
});

global.fetch = mockFetch;

describe('Clients/Edit page CRM rendering', () => {
  const defaultProps = {
    client: {
      id: 'client_123',
      name: 'Jane Doe',
      email: 'jane@example.com',
      phone: '+33123456789',
      company_name: 'Acme',
      company_id: 'acme-1',
      country: 'FR',
      address: {
        street: '1 Rue de Test',
        city: 'Paris',
        postal_code: '75001'
      }
    },
    errors: {},
    forms: [
      { id: 'form_1', name: 'Main KYB form' }
    ],
    current_form_id: 'form_1',
    confirm_message: null,
    attempted_form_id: null,
    has_crm_link: false,
    has_active_crm_connection: true,
    confirm_replace_required: false
  };

  beforeEach(() => {
    mockFetch.mockReset();
    localStorageState.clear();
    window.localStorage.clear();
    mockFetch.mockImplementation((input: RequestInfo | URL) => {
      const url = String(input);

      if (url === '/countries?v=3') {
        return Promise.resolve({
          ok: true,
          json: async () => [
            { name: 'France', code: 'FR' },
            { name: 'United States', code: 'US' }
          ]
        });
      }

      if (url === '/clients/client_123/crm_match_suggestions') {
        return Promise.resolve({
          ok: true,
          json: async () => ({ match: null })
        });
      }

      throw new Error(`Unexpected fetch call: ${url}`);
    });
  });

  it('shows the CRM sync widget for unlinked clients with an active CRM connection', async () => {
    const { getByText, queryByText } = render(ClientsEdit, { props: defaultProps });

    await waitFor(() => {
      expect(getByText('CRM Integration')).toBeInTheDocument();
      expect(getByText(/This client is not linked to your CRM\./i)).toBeInTheDocument();
    });

    expect(queryByText('CRM Data are linked')).not.toBeInTheDocument();
    expect(mockFetch).toHaveBeenCalledWith('/clients/client_123/crm_match_suggestions');
  });

  it('shows the CRM prefill box and hides the sync widget for linked clients', async () => {
    const { getByText, queryByText } = render(ClientsEdit, {
      props: {
        ...defaultProps,
        has_crm_link: true
      }
    });

    await waitFor(() => {
      expect(getByText('CRM Data are linked')).toBeInTheDocument();
      expect(getByText('Complete with CRM data')).toBeInTheDocument();
    });

    expect(queryByText('CRM Integration')).not.toBeInTheDocument();
    expect(queryByText(/This client is not linked to your CRM\./i)).not.toBeInTheDocument();
    expect(mockFetch).not.toHaveBeenCalledWith('/clients/client_123/crm_match_suggestions');
  });

  it('shows the linked CRM notice once and persists dismissal in localStorage', async () => {
    const { getByText, queryByText } = render(ClientsEdit, {
      props: {
        ...defaultProps,
        has_crm_link: true,
        crm_sync_status: {
          linked: true,
          connection_active: true,
          auto_updates_on_edit: true,
          provider: 'hubspot',
          provider_name: 'HubSpot'
        }
      }
    });

    await waitFor(() => {
      expect(getByText('CRM-linked client')).toBeInTheDocument();
      expect(getByText(/Saving this client updates the linked CRM profile automatically\./i)).toBeInTheDocument();
    });

    expect(getByText(/Linked to HubSpot\. Fetching data is manual, but saving this page automatically pushes profile and company changes back to the CRM\./i)).toBeInTheDocument();

    await fireEvent.click(getByText('Understood'));

    await waitFor(() => {
      expect(queryByText('CRM-linked client')).not.toBeInTheDocument();
    });

    expect(window.localStorage.getItem('quick-kyb.crm-linked-edit-notice.v1')).toBe('dismissed');
    expect(getByText(/Linked to HubSpot\. Fetching data is manual, but saving this page automatically pushes profile and company changes back to the CRM\./i)).toBeInTheDocument();
  });

  it('does not reopen the linked CRM notice after it has already been dismissed in this browser', async () => {
    window.localStorage.setItem('quick-kyb.crm-linked-edit-notice.v1', 'dismissed');

    const { queryByText, getByText } = render(ClientsEdit, {
      props: {
        ...defaultProps,
        has_crm_link: true,
        crm_sync_status: {
          linked: true,
          connection_active: true,
          auto_updates_on_edit: true,
          provider: 'hubspot',
          provider_name: 'HubSpot'
        }
      }
    });

    await waitFor(() => {
      expect(getByText(/Linked to HubSpot\. Fetching data is manual, but saving this page automatically pushes profile and company changes back to the CRM\./i)).toBeInTheDocument();
    });

    expect(queryByText('CRM-linked client')).not.toBeInTheDocument();
  });
});