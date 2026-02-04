import { test, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import NewClient from '../../../../app/frontend/pages/Clients/New.svelte';

test('renders new client form', () => {
  render(NewClient, { props: { user: { email: 'test@example.com' } } });
  expect(screen.getByText('New client')).toBeInTheDocument();
  // label text 'Name' should be associated with an input
  expect(screen.getByLabelText('Name')).toBeInTheDocument();
});
