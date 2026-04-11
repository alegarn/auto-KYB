import { test, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { renderPage } from '../helpers/renderPage';
import { mockPageProps, updatePageProps, resetPageProps } from '../../mocks/inertia';

vi.mock('@/lib/invitation-delivery', () => ({
  sendInvitation: vi.fn(),
  skipInvitation: vi.fn(),
}));

import { sendInvitation, skipInvitation } from '@/lib/invitation-delivery';
import InvitationDeliveryDecision from '../../../../app/frontend/pages/Clients/InvitationDeliveryDecision.svelte';

const defaultProps = {
  client_form_id: 42,
  client: { name: 'Acme Corp', email: 'acme@example.com' },
  form: { name: 'KYB Form' },
  has_email: true,
  auto_send: false,
  flash_message: null,
};

beforeEach(() => {
  vi.clearAllMocks();
  resetPageProps();
});

test('renders modal title when has_email is true', () => {
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: defaultProps,
  });
  expect(screen.getByText('Send portal access now?')).toBeInTheDocument();
});

test('shows client email in modal when has_email is true', () => {
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: defaultProps,
  });
  expect(screen.getAllByText('acme@example.com').length).toBeGreaterThan(0);
});

test('shows no-email message when has_email is false', () => {
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: { ...defaultProps, has_email: false },
  });
  expect(screen.getByText(/does not have an email address yet/)).toBeInTheDocument();
});

test('shows client name and form name in info box', () => {
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: defaultProps,
  });
  expect(screen.getByText('Acme Corp')).toBeInTheDocument();
  expect(screen.getByText('KYB Form')).toBeInTheDocument();
});

test('"Send now" button is disabled when has_email is false', () => {
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: { ...defaultProps, has_email: false },
  });
  expect(screen.getByRole('button', { name: 'Confirm' })).toBeDisabled();
});

test('clicking "Send now" calls sendInvitation with client_form_id', async () => {
  const user = userEvent.setup();
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: defaultProps,
  });
  await user.click(screen.getByRole('button', { name: 'Confirm' }));
  await waitFor(() => {
    expect(sendInvitation).toHaveBeenCalledWith(42, { onFinish: expect.any(Function) });
  });
});

test('clicking "Not now" calls skipInvitation with client_form_id', async () => {
  const user = userEvent.setup();
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: defaultProps,
  });
  await user.click(screen.getByRole('button', { name: 'Cancel' }));
  await waitFor(() => {
    expect(skipInvitation).toHaveBeenCalledWith(42);
  });
});

test('displays flash_message prop as an alert', () => {
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: { ...defaultProps, flash_message: 'Something went wrong' },
  });
  expect(screen.getByRole('alert')).toHaveTextContent('Something went wrong');
});

test('displays flash alert from page props', () => {
  updatePageProps({
    props: { ...mockPageProps.props, flash: { alert: 'Page-level alert' } },
  });
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: defaultProps,
  });
  expect(screen.getByRole('alert')).toHaveTextContent('Page-level alert');
});

test('auto_send with has_email calls sendInvitation on mount', async () => {
  renderPage({
    pageName: 'Clients/InvitationDeliveryDecision',
    component: InvitationDeliveryDecision,
    props: { ...defaultProps, auto_send: true, has_email: true },
  });
  await waitFor(() => {
    expect(sendInvitation).toHaveBeenCalledWith(42, { onFinish: expect.any(Function) });
  });
});
