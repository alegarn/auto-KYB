import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, fireEvent, waitFor } from '@testing-library/svelte';
import CrmMatchBanner from '/components/CrmMatchBanner.svelte';
import { router } from '@inertiajs/svelte';

const mockFetch = vi.fn();
global.fetch = mockFetch;

vi.mock('@inertiajs/svelte', () => ({
  router: {
    post: vi.fn(),
  },
}));

describe('CrmMatchBanner', () => {
  beforeEach(() => {
    mockFetch.mockReset();
    vi.mocked(router.post).mockReset();
  });

  it('renders nothing initially when loading and resolves no match state', async () => {
    // If no client email, should just render no match directly
    const { container } = render(CrmMatchBanner, { clientId: 'client_789' });
    
    // No match -> renders "Create contact in CRM" button
    await waitFor(() => {
      expect(container.textContent).toMatch(/This client is not linked/);
    });
  });

  it('fetches contact matches when email is provided and displays match UI', async () => {
    const mockMatch = { external_contact_id: 'hub_123', name: 'Jane Test', email: 'jane@test.local' };
    mockFetch.mockResolvedValueOnce({ json: async () => ({ match: mockMatch }) });

    const { getByText } = render(CrmMatchBanner, { clientId: 'client_789', clientEmail: 'jane@test.local' });
    
    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith('/clients/client_789/crm_match_suggestions');
      expect(getByText('CRM Connection Available')).toBeInTheDocument();
      expect(getByText('Jane Test')).toBeInTheDocument();
    });
  });

  it('submits link contact correctly when "Link this contact" is clicked', async () => {
    const mockMatch = { external_contact_id: 'hub_123', name: 'Jane Test', email: 'jane@test.local' };
    mockFetch.mockResolvedValueOnce({ json: async () => ({ match: mockMatch }) });

    const { getByText } = render(CrmMatchBanner, { clientId: 'client_789', clientEmail: 'jane@test.local' });
    
    await waitFor(() => getByText('Link this contact'));
    await fireEvent.click(getByText('Link this contact'));

    expect(router.post).toHaveBeenCalledWith(
      '/clients/client_789/link_crm_contact',
      { external_contact_id: 'hub_123' },
      expect.any(Object)
    );
  });

  it('hides the match and shows unlinked UI when Dismiss is clicked', async () => {
    const mockMatch = { external_contact_id: 'hub_123', name: 'Jane Test', email: 'jane@test.local' };
    mockFetch.mockResolvedValueOnce({ json: async () => ({ match: mockMatch }) });

    const { getByText, queryByText } = render(CrmMatchBanner, { clientId: 'client_789', clientEmail: 'jane@test.local' });
    
    await waitFor(() => getByText('Dismiss'));
    await fireEvent.click(getByText('Dismiss'));

    await waitFor(() => {
      expect(queryByText('CRM Connection Available')).toBeNull();
      expect(getByText(/This client is not linked/i)).toBeInTheDocument();
    });
  });

  it('submits create contact correctly when "Create contact in CRM" is clicked', async () => {
    // Return no match to ensure we get to the create button
    mockFetch.mockResolvedValueOnce({ json: async () => ({ match: null }) });

    const { getByText } = render(CrmMatchBanner, { clientId: 'client_789', clientEmail: 'jane@test.local' });
    
    await waitFor(() => getByText('Create contact in CRM'));
    await fireEvent.click(getByText('Create contact in CRM'));

    expect(router.post).toHaveBeenCalledWith(
      '/clients/client_789/create_crm_contact',
      {},
      expect.any(Object)
    );
  });
});
