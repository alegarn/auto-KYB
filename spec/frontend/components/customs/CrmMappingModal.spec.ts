import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import CrmMappingModal from "../../../../app/frontend/components/customs/CrmMappingModal.svelte";

describe('CrmMappingModal', () => {
  const defaultProps = {
    open: true,
    crmProperties: { 
      hubspot: {
        contact: [
          { name: 'company', label: 'Company', type: 'string' },
          { name: 'age', label: 'Age', type: 'number' }
        ],
        company: []
      }
    },
    fields: [
      { id: 'f1', label: 'Company Name', field_type: 'text', required: false, position: 0, metadata: {} },
      { id: 'f2', label: 'Is Active', field_type: 'checkbox', required: false, position: 1, metadata: {} }
    ]
  };

  it('renders the form field label and data type', () => {
    render(CrmMappingModal, { props: { ...defaultProps, onsave: vi.fn() } });
    
    expect(screen.getByText('Company Name')).toBeInTheDocument();
    expect(screen.getByText('(string)')).toBeInTheDocument();
    expect(screen.getByText('Is Active')).toBeInTheDocument();
    expect(screen.getByText('(boolean)')).toBeInTheDocument();
  });

  it('shows a warning message when data types are incompatible', async () => {
    const user = userEvent.setup();
    render(CrmMappingModal, { props: { ...defaultProps, onsave: vi.fn() } });
    
    const selects = screen.getAllByRole('combobox');
    // Map 'Is Active' (boolean) to HubSpot 'Age' (number)
    await user.selectOptions(selects[1], 'contact:age');

    expect(screen.getByText(/Type mismatch: boolean vs number/i)).toBeInTheDocument();
  });

  it('does not show a warning message when types are compatible', async () => {
    const user = userEvent.setup();
    render(CrmMappingModal, { props: { ...defaultProps, onsave: vi.fn() } });
    
    const selects = screen.getAllByRole('combobox');
    // Map 'Company Name' (text) to HubSpot 'Company' (string)
    await user.selectOptions(selects[0], 'contact:company');

    expect(screen.queryByText(/Type mismatch/i)).not.toBeInTheDocument();
  });

  it('dispatches the save event with updated metadata', async () => {
    const user = userEvent.setup();
    const onSaveMock = vi.fn();

    render(CrmMappingModal, { 
      props: {
        ...defaultProps,
        onsave: onSaveMock 
      }
    });

    const selects = screen.getAllByRole('combobox');
    await user.selectOptions(selects[0], 'contact:company');

    const saveButton = screen.getByRole('button', { name: /save mapping/i });
    await user.click(saveButton);

    expect(onSaveMock).toHaveBeenCalled();
    const eventPayload = onSaveMock.mock.calls[0][0];
    
    expect(eventPayload.fields[0].metadata.crm_mapping.hubspot).toEqual({
      type: 'existing',
      object_type: 'contact',
      property_name: 'company'
    });
  });
});
