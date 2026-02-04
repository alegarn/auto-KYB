import { test, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';

import EditClient from '../../../../app/frontend/pages/Clients/Edit.svelte';

test('renders edit client form with pre-filled values', () => {
  const client = { id: '1', name: 'Acme', company_name: 'Acme Inc.', email: 'a@a.com', phone: '123' };
  render(EditClient, { props: { client, errors: {} } });
  expect(screen.getByText('Edit client')).toBeInTheDocument();
  expect(screen.getByDisplayValue('Acme')).toBeInTheDocument();
});
