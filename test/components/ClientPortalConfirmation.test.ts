import { test, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import Confirmation from '../../app/frontend/pages/ClientPortal/Confirmation.svelte';

test('renders client and form name and CTAs', () => {
  const client = { id: 1, name: 'ACME Corp' };
  const form = { id: 2, name: 'KYC Form' };

  render(Confirmation, { props: { client, form } });

  expect(screen.getByText(/Submission Confirmed/i)).toBeInTheDocument();
  expect(screen.getByText(/ACME Corp/)).toBeInTheDocument();
  expect(screen.getByText(/KYC Form/)).toBeInTheDocument();
  expect(screen.getByRole('link', { name: /Return to Home/i })).toBeInTheDocument();
});
