import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import Index from '../../../../app/frontend/pages/Settings/Index.svelte';

// Mock the router
vi.mock('@inertiajs/svelte', () => ({
  router: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
  },
  page: {
    subscribe: (fn: any) => {
      fn({ url: '/settings', props: {} });
      return () => {};
    }
  }
}));

// Mock routes
vi.mock('@/routes', () => ({
  sign_up_path: () => '/sign_up',
}));

describe('Settings/Index.svelte - CRM Integrations', () => {
  const defaultProps = {
    user: {
      email: 'test@example.com',
      created_at: '2026-01-01T00:00:00Z',
    }
  };

  it('renders the CRM Integrations section', () => {
    render(Index, { props: defaultProps });
    
    expect(screen.getByText('CRM Integrations')).toBeInTheDocument();
    expect(screen.getByText('Connect your CRM to automatically export client data.')).toBeInTheDocument();
  });

  it('renders the available CRMs', () => {
    render(Index, { props: defaultProps });
    
    expect(screen.getByText('HubSpot')).toBeInTheDocument();
    expect(screen.getByText('Salesforce')).toBeInTheDocument();
    expect(screen.getByText('Zoho CRM')).toBeInTheDocument();
  });

  it('shows connected status for HubSpot (dummy data)', () => {
    render(Index, { props: defaultProps });
    
    // HubSpot is connected by default in our dummy data
    const hubspotContainer = screen.getByText('HubSpot').closest('div')?.parentElement;
    expect(hubspotContainer).toBeInTheDocument();
    
    if (hubspotContainer) {
      expect(hubspotContainer.textContent).toContain('Connected');
      expect(hubspotContainer.textContent).toContain('Test');
      expect(hubspotContainer.textContent).toContain('Disconnect');
    }
  });

  it('shows disconnected status for Salesforce (dummy data)', () => {
    render(Index, { props: defaultProps });
    
    // Salesforce is disconnected by default in our dummy data
    const salesforceContainer = screen.getByText('Salesforce').closest('div')?.parentElement;
    expect(salesforceContainer).toBeInTheDocument();
    
    if (salesforceContainer) {
      expect(salesforceContainer.textContent).toContain('Not connected');
      expect(salesforceContainer.textContent).toContain('Connect');
    }
  });
});