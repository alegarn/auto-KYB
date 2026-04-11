import { test, expect } from 'vitest';
import { screen } from '@testing-library/svelte';
import NewClient from '../../../../app/frontend/pages/Clients/New.svelte';
import { renderPage } from '../helpers/renderPage';

test('renders new client form', () => {
  renderPage({
    pageName: 'Clients/New',
    component: NewClient,
    props: { user: { email: 'test@example.com' } },
  });
  expect(screen.getByText('New client')).toBeInTheDocument();
  expect(screen.getByLabelText(/Full Name/i)).toBeInTheDocument();
  expect(
    screen.getByText(/No automatic email can be sent to the client without a valid email address/i)
  ).toBeInTheDocument();
});
