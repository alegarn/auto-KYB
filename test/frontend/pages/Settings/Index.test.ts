import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { mockPageProps, resetPageProps, updatePageProps } from '../../mocks/inertia';
import Index from '../../../../app/frontend/pages/Settings/Index.svelte';

vi.mock('@/routes', () => ({
  sign_up_path: () => '/sign_up',
}));

if (!Element.prototype.animate) {
  Object.defineProperty(Element.prototype, 'animate', {
    configurable: true,
    value: vi.fn(() => ({
      cancel: vi.fn(),
      finish: vi.fn(),
      onfinish: null,
      oncancel: null,
      playState: 'finished',
    })),
  });
}

describe('Settings/Index.svelte', () => {
  const defaultProps = {
    user: {
      email: 'test@example.com',
      created_at: '2026-01-01T00:00:00Z',
      crm_auto_sync_on_portal_submit: false,
    },
    crm_connections: [
      { id: 1, provider: 'hubspot', status: 'active' },
      { id: 2, provider: 'salesforce', status: 'inactive' },
    ],
    available_providers: ['hubspot', 'salesforce', 'zoho'],
    client_invitation_email_setting: {
      auto_send: false,
      subject_template: null,
      body_template: null,
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
    document.body.innerHTML = '';
    resetPageProps();
    updatePageProps({
      props: {
        ...mockPageProps.props,
        auth: { features: { crm: { allowed: true } } },
      },
    });
  });

  it('renders the current settings headings', () => {
    render(Index, { props: defaultProps });

    expect(screen.getByRole('heading', { name: 'Settings' })).toBeInTheDocument();
    expect(screen.getByText('CRM Integrations')).toBeInTheDocument();
    expect(screen.getByText('CRM sync behavior')).toBeInTheDocument();
    expect(screen.getByText('Client invite email and template')).toBeInTheDocument();
  });

  it('shows the CRM provider rows when the CRM section is expanded', async () => {
    render(Index, { props: defaultProps });

    const crmManageButton = screen.getAllByRole('button', { name: 'Manage' })[2];
    await fireEvent.click(crmManageButton);

    await waitFor(() => {
      expect(screen.getByText('HubSpot')).toBeInTheDocument();
      expect(screen.getByText('Salesforce')).toBeInTheDocument();
      expect(screen.getByText('Connected — data will be exported automatically.')).toBeInTheDocument();
      expect(screen.getAllByText('Not connected.')[1]).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Test' })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Disconnect' })).toBeInTheDocument();
      expect(screen.getAllByRole('button', { name: 'Connect' })).toHaveLength(2);
    });
  });

  it('shows the CRM sync behavior copy when expanded', async () => {
    render(Index, { props: defaultProps });

    const crmSyncManageButton = screen.getAllByRole('button', { name: 'Manage' })[3];
    await fireEvent.click(crmSyncManageButton);

    await waitFor(() => {
      expect(screen.getByText('Automatic sync after client portal submission')).toBeInTheDocument();
      expect(screen.getByText('Portal submissions stay local until you trigger a manual CRM update.')).toBeInTheDocument();
    });
  });

  it('shows the invite email template editor when expanded', async () => {
    render(Index, { props: defaultProps });

    const inviteManageButton = screen.getAllByRole('button', { name: 'Manage' })[4];
    await fireEvent.click(inviteManageButton);

    await waitFor(() => {
      expect(screen.getByText('Send client portal invite automatically')).toBeInTheDocument();
      expect(screen.getByText('Save email template')).toBeInTheDocument();
    });
  });
});