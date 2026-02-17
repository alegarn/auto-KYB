import { test, expect, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';

// Mock countries loader to avoid network/URL parsing in tests
vi.mock('/lib/countries', () => ({
  fetchCountriesData: async () => [{ name: 'United States', code: 'US', flag: '🇺🇸' }]
}));

import EditClient from '../../../../app/frontend/pages/Clients/Edit.svelte';

test('renders edit client form with pre-filled values', () => {
  const client = { id: '1', name: 'Acme', company_name: 'Acme Inc.', email: 'a@a.com', phone: '123' };
  const { container } = render(EditClient, { props: { client, errors: {}, session_id: 'session-123', forms: [] } });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);
  
  expect(withinSection.getByText('Edit client')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('Acme')).toBeInTheDocument();
});

test('renders all client fields with pre-filled values', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    email: 'contact@acme.com',
    phone: '555-1234',
    address: {
      street: '123 Main St',
      city: 'Metropolis',
      postal_code: '12345',
      country: 'USA'
    }
  };
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms: [] }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByDisplayValue('Acme Corp')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('Acme Inc.')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('contact@acme.com')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('555-1234')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('123 Main St')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('Metropolis')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('12345')).toBeInTheDocument();
  expect(withinSection.getByDisplayValue('USA')).toBeInTheDocument();
});

test('displays array-based errors', () => {
  const errors = ['Error 1', 'Error 2'];
  const { container } = render(EditClient, {
    props: {
      client: { id: '1', name: 'Acme', email: 'a@a.com' },
      errors,
      session_id: 'session-123',
      forms: []
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('Error 1')).toBeInTheDocument();
  expect(withinSection.getByText('Error 2')).toBeInTheDocument();
});

test('displays object-based field errors', () => {
  const errors = { name: ['Name is required'], email: ['Email is invalid'] };
  const { container } = render(EditClient, {
    props: {
      client: { id: '1', name: '', email: 'invalid' },
      errors,
      session_id: 'session-123',
      forms: []
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('name: Name is required')).toBeInTheDocument();
  expect(withinSection.getByText('email: Email is invalid')).toBeInTheDocument();
});

test('shows form dropdown for active client with forms available', () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const forms = [
    { id: '1', name: 'Form A' },
    { id: '2', name: 'Form B' }
  ];
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Target the linked-form select specifically to avoid matching country select
  const select = container.querySelector('#client-form') as HTMLSelectElement;
  expect(select).toBeInTheDocument();
  expect(withinSection.getByText('Form A')).toBeInTheDocument();
  expect(withinSection.getByText('Form B')).toBeInTheDocument();
});

test('shows read-only form for validated client', () => {
  const client = {
    id: '1',
    name: 'Acme',
    email: 'a@a.com',
    status: 'validated',
    form_id: '1'
  };
  const forms = [{ id: '1', name: 'Form A' }];
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Use getAllByText and find one in validated span
  const formATexts = withinSection.getAllByText('Form A');
  expect(formATexts.length).toBeGreaterThan(0);
  expect(withinSection.getByText('validated')).toBeInTheDocument();
  const select = withinSection.queryByRole('combobox');
  expect(select).not.toBeInTheDocument();
});

test('shows "None" when validated client has no form', () => {
  const client = {
    id: '1',
    name: 'Apex',
    email: 'b@b.com',
    status: 'validated',
    client_form_id: null,
    form_id: null,
    form: null
  };
  const forms = [{ id: '1', name: 'Form A' }];
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms }
  });

  // Check for presence of <em> element with "None" text
  const emElement = container.querySelector('section em');
  expect(emElement).not.toBeNull();
  expect(emElement?.textContent).toBe('None');
});

test('does not show form dropdown when no forms available', () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms: [] }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Ensure the linked-form select is not present (country select may exist)
  const select = container.querySelector('#client-form');
  expect(select).toBeNull();
});

test('shows confirmation modal when clicking form select for active client', async () => {
  const user = userEvent.setup();
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const forms = [{ id: '1', name: 'Form A' }];
  const { container } = render(EditClient, {
    props: {
      client,
      errors: {},
      session_id: 'session-123',
      forms,
      confirm_message: 'Custom confirm message'
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Target the linked-form select specifically and trigger pointerdown
  const select = container.querySelector('#client-form') as HTMLSelectElement;
  select.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));

  // Wait for modal dialog to appear
  const dialog = await screen.findByRole('dialog');
  expect(within(dialog).getByText('Please confirm')).toBeInTheDocument();
  expect(within(dialog).getByText('Custom confirm message')).toBeInTheDocument();
});

test('does not show modal when client status is not active', () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'validated' };
  const forms = [{ id: '1', name: 'Form A' }];
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Check that modal doesn't appear within the main section (not in sidebar)
  expect(withinSection.queryByText('Please confirm')).not.toBeInTheDocument();
});

test('closes modal when clicking Go back', async () => {
  const user = userEvent.setup();
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const forms = [{ id: '1', name: 'Form A' }];
  const { container } = render(EditClient, {
    props: {
      client,
      errors: {},
      session_id: 'session-123',
      forms
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  const select = container.querySelector('#client-form') as HTMLSelectElement;
  select.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));

  const dialog = await screen.findByRole('dialog');
  expect(within(dialog).getByText('Please confirm')).toBeInTheDocument();

  // Click the modal's Cancel button
  const cancelButton = within(dialog).getByRole('button', { name: 'Cancel' });
  await user.click(cancelButton);

  await waitFor(() => {
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});

test('confirms replace and closes modal when clicking Continue', async () => {
  const user = userEvent.setup();
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const forms = [{ id: '1', name: 'Form A' }];
  const { container } = render(EditClient, {
    props: {
      client,
      errors: {},
      session_id: 'session-123',
      forms
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  const select = container.querySelector('#client-form') as HTMLSelectElement;
  select.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));

  const dialog = await screen.findByRole('dialog');
  expect(within(dialog).getByText('Please confirm')).toBeInTheDocument();

  // Click Continue in modal
  const continueButton = within(dialog).getByRole('button', { name: 'Continue' });
  await user.click(continueButton);

  await waitFor(() => {
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});

test('uses attempted_form_id when provided', async () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const forms = [
    { id: '1', name: 'Form A' },
    { id: '2', name: 'Form B' }
  ];
  const { container } = render(EditClient, {
    props: {
      client,
      errors: {},
      session_id: 'session-123',
      forms,
      attempted_form_id: '2'
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  await waitFor(() => {
    const sel = container.querySelector('#client-form');
    expect(sel).not.toBeNull();
  });
  const select = container.querySelector('#client-form') as HTMLSelectElement;
  expect(select.value).toBe('2');
});

test('defaults to first form when no attempted_form_id provided', async () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const forms = [
    { id: '1', name: 'Form A' },
    { id: '2', name: 'Form B' }
  ];
  const { container } = render(EditClient, {
    props: {
      client,
      errors: {},
      session_id: 'session-123',
      forms
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  await waitFor(() => {
    const sel = container.querySelector('#client-form');
    expect(sel).not.toBeNull();
  });
  const select = container.querySelector('#client-form') as HTMLSelectElement;
  expect(select.value).toBe('1');
});

test('shows cancel button with correct href', () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com' };
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms: [] }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Find cancel button within main section
  const cancelButton = withinSection.getByRole('link', { name: 'Cancel' });
  expect(cancelButton).toBeInTheDocument();
  expect(cancelButton.getAttribute('href') || '').toContain('/clients/1');
});

test('renders submit button', () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com' };
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms: [] }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Find submit button within main section
  const submitButton = withinSection.getByRole('button', { name: 'Update client' });
  expect(submitButton).toBeInTheDocument();
  expect(submitButton).toHaveAttribute('type', 'submit');
});

test('shows error styling on fields with errors', async () => {
  const errors = { name: ['Name is required'] };
  const { container } = render(EditClient, {
    props: {
      client: { id: '1', name: '', email: 'a@a.com' },
      errors,
      session_id: 'session-123',
      forms: []
    }
  });

  // Use id to find the name input
  await waitFor(() => {
    const ni = container.querySelector('#client-name');
    expect(ni).not.toBeNull();
  });
  const nameInput = container.querySelector<HTMLInputElement>('#client-name');
  // The component should add error styling
  expect(nameInput).not.toBeNull();
  expect((nameInput?.className || '')).toContain('border-rose-600');
});

test('includes confirm_replace hidden input', () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com' };
  render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms: [] }
  });

  const hiddenInput = document.querySelector('input[name="client_form[confirm_replace]"]');
  expect(hiddenInput).toBeInTheDocument();
  expect(hiddenInput).toHaveAttribute('value', 'false');
});

test('shows client email in header', () => {
  const client = { id: '1', name: 'Acme', email: 'contact@acme.com' };
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms: [] }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Find email in header section (within main section)
  const emailTexts = withinSection.getAllByText('contact@acme.com');
  expect(emailTexts.length).toBeGreaterThan(0);
});
