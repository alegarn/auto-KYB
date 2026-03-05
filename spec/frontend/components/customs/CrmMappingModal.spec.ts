import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import CrmMappingModal from "/components/customs/CrmMappingModal.svelte";

describe('CrmMappingModal', () => {
  const defaultProps = {
    open: true,
    crmProperties: { 
      hubspot: [{ name: 'company', label: 'Company' }] 
    },
    fields: [
      { id: 'f1', label: 'Company', field_type: 'text' }
    ]
  };

  it('renders the form field label "Company"', () => {
    // Note: Provide mock onsave handler
    render(CrmMappingModal, { props: { ...defaultProps, onsave: vi.fn() } });
    
    // Verifies the modal is displaying the form field's label
    expect(screen.getByText('Company')).toBeInTheDocument();
  });

  it('auto-selects the existing HubSpot property `company` because of the fuzzy matching normalizer', () => {
    render(CrmMappingModal, { props: { ...defaultProps, onsave: vi.fn() } });
    
    const selects = screen.getAllByRole('combobox');
    expect(selects[0]).toHaveValue('company');
  });

  it('dispatches the save event mapped correctly to type: "custom" when choosing "+ Create as Custom Property"', async () => {
    const user = userEvent.setup();
    const onSaveMock = vi.fn();

    render(CrmMappingModal, { 
      props: {
        ...defaultProps,
        onsave: onSaveMock 
      }
    });

    const select = screen.getAllByRole('combobox')[0];
    
    await user.selectOptions(select, '+ Create as Custom Property');

    const saveButton = screen.getByRole('button', { name: /save mapping/i });
    await user.click(saveButton);

    expect(onSaveMock).toHaveBeenCalled();
    const eventPayload = onSaveMock.mock.calls[0][0]; // Array of updatedFields
    
    expect(JSON.stringify(eventPayload)).toMatch(/"type":"custom"/);
  });
});
