import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor } from '@testing-library/svelte';
import ClientsNew from '@/pages/Clients/New.svelte';

const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('Clients/New page CRM rendering', () => {
  const defaultProps = {
    user: {
      email: 'owner@example.com'
    },
    errors: {},
    forms: [
      { id: 'form_1', name: 'Main KYB form' }
    ],
    has_active_crm_connection: false
  };

  beforeEach(() => {
    mockFetch.mockReset();
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

      throw new Error(`Unexpected fetch call: ${url}`);
    });
  });

  it('does not render CRM UI when there is no active CRM connection', async () => {
    const { getByText, queryByText, container } = render(ClientsNew, {
      props: defaultProps
    });

    await waitFor(() => {
      expect(getByText('New client')).toBeInTheDocument();
      expect(getByText('Form to link')).toBeInTheDocument();
    });

    expect(queryByText('CRM Integration')).not.toBeInTheDocument();
    expect(queryByText('Do not sync with CRM yet')).not.toBeInTheDocument();
    expect(container.querySelector('input[name="crm[strategy]"]')).toBeNull();
    expect(mockFetch).toHaveBeenCalledTimes(1);
    expect(mockFetch).toHaveBeenCalledWith('/countries?v=3');
  });
});