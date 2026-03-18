import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, fireEvent, waitFor } from '@testing-library/svelte';
import CrmSyncWidget from '/components/CrmSyncWidget.svelte';

const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('CrmSyncWidget', () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  it('renders default view correctly with "skip"', () => {
    const onSyncDataChanged = vi.fn();
    const { getByLabelText } = render(CrmSyncWidget, { onSyncDataChanged });

    const skipRadio = getByLabelText('Do not sync with CRM yet') as HTMLInputElement;
    expect(skipRadio.checked).toBe(true);
    // Component sets default on mount
  });

  it('allows switching to "create" strategy', async () => {
    const onSyncDataChanged = vi.fn();
    const { getByLabelText } = render(CrmSyncWidget, { onSyncDataChanged });

    await fireEvent.click(getByLabelText('Create new contact in CRM'));
    
    await waitFor(() => {
      expect(onSyncDataChanged).toHaveBeenCalledWith(expect.objectContaining({ strategy: 'create' }));
    });
  });

  it('shows search interface for "link" strategy and supports searching', async () => {
    const onSyncDataChanged = vi.fn();
    const mockContacts = [{ external_contact_id: '123', name: 'John Doe', email: 'john@example.com' }];
    mockFetch.mockResolvedValueOnce({ json: async () => mockContacts });

    const { getByLabelText, getByPlaceholderText, getByText, getByRole } = render(CrmSyncWidget, { onSyncDataChanged });
    await fireEvent.click(getByLabelText('Link existing CRM contact'));

    const searchInput = getByPlaceholderText('Search by email or name...');
    expect(searchInput).toBeInTheDocument();

    await fireEvent.input(searchInput, { target: { value: 'john' } });
    await fireEvent.click(getByRole('button', { name: 'Search' }));

    expect(mockFetch).toHaveBeenCalledWith('/crm/imports?q=john');

    await waitFor(() => {
      expect(getByText('John Doe')).toBeInTheDocument();
      expect(getByText('john@example.com')).toBeInTheDocument();
    });
  });

  it('selects a contact and displays linked view', async () => {
    const onSyncDataChanged = vi.fn();
    const mockContacts = [{ external_contact_id: '123', name: 'John Doe', email: 'john@example.com' }];
    mockFetch.mockResolvedValueOnce({ json: async () => mockContacts });

    const { getByLabelText, getByPlaceholderText, getByRole, getByText, queryByPlaceholderText } = render(CrmSyncWidget, { onSyncDataChanged });
    await fireEvent.click(getByLabelText('Link existing CRM contact'));

    await fireEvent.input(getByPlaceholderText('Search by email or name...'), { target: { value: 'john' } });
    await fireEvent.click(getByRole('button', { name: 'Search' }));

    await waitFor(() => getByText('Select'));
    await fireEvent.click(getByText('Select'));

    await waitFor(() => {
      expect(queryByPlaceholderText('Search by email or name...')).toBeNull();
      expect(getByText('Linked Contact')).toBeInTheDocument();
      expect(onSyncDataChanged).toHaveBeenCalledWith({
        strategy: 'link',
        external_contact_id: '123',
        prefillData: mockContacts[0]
      });
    });
  });

  it('shows no contacts found message', async () => {
    const onSyncDataChanged = vi.fn();
    mockFetch.mockResolvedValueOnce({ json: async () => [] });

    const { getByLabelText, getByPlaceholderText, getByRole, getByText } = render(CrmSyncWidget, { onSyncDataChanged });
    await fireEvent.click(getByLabelText('Link existing CRM contact'));

    await fireEvent.input(getByPlaceholderText('Search by email or name...'), { target: { value: 'nobody' } });
    await fireEvent.click(getByRole('button', { name: 'Search' }));

    await waitFor(() => {
      expect(getByText('No contacts found.')).toBeInTheDocument();
    });
  });
});
