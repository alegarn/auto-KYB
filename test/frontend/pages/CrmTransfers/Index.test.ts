import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import Index from '../../../../app/frontend/pages/CrmTransfers/Index.svelte';

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
      fn({ url: '/crm_transfers', props: {} });
      return () => {};
    }
  }
}));

// Mock routes
vi.mock('@/routes', () => ({
  dashboard_path: () => '/dashboard',
}));

describe('CrmTransfers/Index.svelte', () => {
  it('renders the page title and description', () => {
    render(Index);
    
    expect(screen.getByText('CRM Transfer History')).toBeInTheDocument();
    expect(screen.getByText('View the status of data exports to your connected CRMs.')).toBeInTheDocument();
  });

  it('renders the table headers', () => {
    render(Index);
    
    expect(screen.getByText('Date')).toBeInTheDocument();
    expect(screen.getByText('Client')).toBeInTheDocument();
    expect(screen.getByText('CRM')).toBeInTheDocument();
    expect(screen.getByText('Status')).toBeInTheDocument();
    expect(screen.getByText('Details')).toBeInTheDocument();
  });

  it('renders dummy transfer data', () => {
    render(Index);
    
    // Check for clients
    expect(screen.getAllByText('Acme Corp').length).toBeGreaterThan(0);
    expect(screen.getByText('Globex Inc')).toBeInTheDocument();
    expect(screen.getByText('Initech')).toBeInTheDocument();
    
    // Check for CRMs
    expect(screen.getAllByText('HubSpot').length).toBeGreaterThan(0);
    expect(screen.getByText('Salesforce')).toBeInTheDocument();
    expect(screen.getByText('Zoho CRM')).toBeInTheDocument();
    
    // Check for statuses
    expect(screen.getAllByText('Success').length).toBeGreaterThan(0);
    expect(screen.getByText('Failed')).toBeInTheDocument();
    expect(screen.getByText('Pending')).toBeInTheDocument();
    
    // Check for error message
    expect(screen.getByText('API rate limit exceeded')).toBeInTheDocument();
  });

  it('renders back to dashboard button', () => {
    render(Index);
    
    const backButton = screen.getByText('Back to dashboard');
    expect(backButton).toBeInTheDocument();
    expect(backButton.closest('a')).toHaveAttribute('href', '/dashboard');
  });
});