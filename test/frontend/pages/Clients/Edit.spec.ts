import { test, expect } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';

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

  // Use role instead of label to avoid label association issues
  const select = withinSection.getByRole('combobox');
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
  expect(emElement).toBeInTheDocument();
  expect(emElement?.textContent).toBe('None');
});

test('does not show form dropdown when no forms available', () => {
  const client = { id: '1', name: 'Acme', email: 'a@a.com', status: 'active' };
  const { container } = render(EditClient, {
    props: { client, errors: {}, session_id: 'session-123', forms: [] }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  const select = withinSection.queryByRole('combobox');
  expect(select).not.toBeInTheDocument();
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

  // Use role instead of label
  const select = withinSection.getByRole('combobox');
  await user.pointer({ target: select, keys: '[MouseLeft]' });

  await waitFor(() => {
    // Use getAllByText and find the modal one (not from sidebar)
    const confirmTexts = screen.getAllByText('Please confirm');
    expect(confirmTexts.length).toBeGreaterThan(0);
    const confirmMessages = screen.getAllByText('Custom confirm message');
    expect(confirmMessages.length).toBeGreaterThan(0);
  });
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

  const select = withinSection.getByRole('combobox');
  await user.pointer({ target: select, keys: '[MouseLeft]' });

  await waitFor(() => {
    // Check modal appears within main section
    expect(withinSection.getByText('Please confirm')).toBeInTheDocument();
  });

  // Find Go back button within modal (using text content since there's also a Cancel button in the form)
  const goBackButton = withinSection.getByRole('button', { name: 'Go back' });
  await user.click(goBackButton);

  await waitFor(() => {
    // Check modal is closed within main section
    expect(withinSection.queryByText('Please confirm')).not.toBeInTheDocument();
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

  const select = withinSection.getByRole('combobox');
  await user.pointer({ target: select, keys: '[MouseLeft]' });

  await waitFor(() => {
    // Check modal appears within main section
    expect(withinSection.getByText('Please confirm')).toBeInTheDocument();
  });

  // Find Continue button within modal
  const continueButton = withinSection.getByRole('button', { name: 'Continue' });
  await user.click(continueButton);

  await waitFor(() => {
    // Check modal is closed within main section
    expect(withinSection.queryByText('Please confirm')).not.toBeInTheDocument();
  });
});

test('uses attempted_form_id when provided', () => {
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

  const select = withinSection.getByRole('combobox') as HTMLSelectElement;
  // The component correctly uses attempted_form_id when provided
  expect(select.value).toBe('2');
});

test('defaults to first form when no attempted_form_id provided', () => {
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

  const select = withinSection.getByRole('combobox') as HTMLSelectElement;
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
  expect(cancelButton).toHaveAttribute('href', '/clients/1');
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

test('shows error styling on fields with errors', () => {
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
  const nameInput = container.querySelector<HTMLInputElement>('#client-name');
  // The component should add error styling
  expect(nameInput).toBeInTheDocument();
  // Check if the input has the error class
  expect(nameInput?.className).toContain('border-rose-600');
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
