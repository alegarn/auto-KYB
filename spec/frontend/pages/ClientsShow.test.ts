import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fireEvent, render, waitFor } from '@testing-library/svelte';
import ClientsShow from '@/pages/Clients/Show.svelte';

const mockFetch = vi.fn();

global.fetch = mockFetch;

describe('Clients/Show page CRM export modal', () => {
  const defaultProps = {
    user: {
      email: 'owner@example.com'
    },
    client: {
      id: 'client_123',
      name: 'Jane Doe',
      company_name: 'Acme',
      company_id: 'acme-1',
      country: 'FR',
      status: 'validated',
      email: 'jane@example.com'
    },
    forms: [],
    client_form: {
      id: 'client_form_123',
      status: 'validated',
      form: {
        name: 'Main KYB form'
      }
    },
    uploaded_files: [],
    file_retention: null,
    crm_connections: [
      { id: 'crm_1', provider: 'hubspot' },
      { id: 'crm_2', provider: 'salesforce' }
    ]
  };

  beforeEach(() => {
    mockFetch.mockReset();
    mockFetch.mockImplementation((input: RequestInfo | URL) => {
      const url = String(input);

      if (url === '/countries?v=3') {
        return Promise.resolve({
          ok: true,
          json: async () => [
            { name: 'France', code: 'FR', flag: 'FR' }
          ]
        });
      }

      if (url === '/clients/client_123/export_to_crm') {
        return Promise.resolve({
          ok: true,
          json: async () => ({
            success: true,
            message: 'Manual CRM export queued. Selected CRM transfers will run in the background and may take a moment to complete.'
          })
        });
      }

      throw new Error(`Unexpected fetch call: ${url}`);
    });
  });

  it('shows that manual CRM export was queued and will run asynchronously', async () => {
    const { getByText, getByLabelText, getByRole, findByText } = render(ClientsShow, {
      props: defaultProps
    });

    await fireEvent.click(getByText('Export to CRM'));
    await fireEvent.click(getByLabelText(/salesforce/i));
    await fireEvent.click(getByRole('button', { name: 'Confirm' }));

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith(
        '/clients/client_123/export_to_crm',
        expect.objectContaining({
          method: 'POST'
        })
      );
    });

    const exportCall = mockFetch.mock.calls.find(([input]) => String(input) === '/clients/client_123/export_to_crm');
    expect(exportCall).toBeDefined();
    expect(JSON.parse(exportCall?.[1]?.body as string)).toEqual({
      crms: ['hubspot', 'salesforce']
    });

    expect(
      await findByText('Manual CRM export queued. Selected CRM transfers will run in the background and may take a moment to complete.')
    ).toBeInTheDocument();
  });
});