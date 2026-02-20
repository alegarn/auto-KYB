import { test, expect, vi, beforeEach } from 'vitest';
import { screen, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { renderPage } from '../helpers/renderPage';

import ShowClient from '../../../../app/frontend/pages/Clients/Show.svelte';

const render = (component: any, options: { props?: Record<string, unknown> } = {}) =>
  {
    const result = renderPage({ pageName: 'Clients/Show', component, props: options.props ?? {} });
    const pageContent = result.container.querySelector('[data-testid="page-test-content"]') as HTMLElement | null;
    if (pageContent) {
      (result.container as any).querySelector = pageContent.querySelector.bind(pageContent);
    }
    return result;
  };

// Mock the routes used by the component
const mockClientsPath = vi.fn(() => '/clients');
const mockDashboardPath = vi.fn(() => '/dashboard');
const mockEditClientPath = vi.fn((id: string) => `/clients/${id}/edit`);
const mockClientPath = vi.fn((id: string) => `/clients/${id}`);
const mockClientFormsPath = vi.fn(() => '/client_forms');

vi.mock('@/routes', () => ({
  clients_path: mockClientsPath,
  dashboard_path: mockDashboardPath,
  edit_client_path: mockEditClientPath,
  client_path: mockClientPath,
  client_forms_path: mockClientFormsPath
}));

// Mock the Inertia router
var mockDelete = vi.fn();
vi.mock('@inertiajs/svelte', async () => {
  const actual = await vi.importActual('@inertiajs/svelte');
  return {
    ...(actual as any),
    router: {
      delete: mockDelete
    }
  };
});

beforeEach(() => {
  vi.clearAllMocks();
});

test('renders client details when client is provided', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    email: 'contact@acme.com',
    phone: '555-1234',
    status: 'active',
    address: {
      street: '123 Main St',
      city: 'Metropolis',
      postcode: '12345',
      country: 'USA'
    }
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('Client details')).toBeInTheDocument();
  expect(withinSection.getByText('Acme Corp')).toBeInTheDocument();
  expect(withinSection.getByText('Acme Inc.')).toBeInTheDocument();
  expect(withinSection.getByText('contact@acme.com')).toBeInTheDocument();
  expect(withinSection.getByText('555-1234')).toBeInTheDocument();
  expect(withinSection.getByText('active')).toBeInTheDocument();
});

test('does not show export button when client_form is null', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // The export button should not be in the document when client_form is null
  const exportButton = withinSection.queryByText('Export Form Responses (CSV)');
  expect(exportButton).not.toBeInTheDocument();
});

test('shows export button when client_form exists', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const clientForm = {
    id: '42',
    form: { name: 'Customer Onboarding' },
    status: 'validated'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: clientForm
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // The export button should be in the document when client_form exists
  const exportButton = withinSection.getByText('Export Form Responses (CSV)');
  expect(exportButton).toBeInTheDocument();
});

test('export button has correct href with client_form.id', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const clientForm = {
    id: '42',
    form: { name: 'Customer Onboarding' },
    status: 'validated'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: clientForm
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Find the export button by its text
  const exportButton = withinSection.getByText('Export Form Responses (CSV)');
  
  // Verify the href attribute contains the client_form.id
  expect(exportButton).toHaveAttribute('href', '/client_forms/42/export_responses.csv');
});

test('export button has target="_blank" and rel="noopener" attributes', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const clientForm = {
    id: '42',
    form: { name: 'Customer Onboarding' },
    status: 'validated'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: clientForm
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Find the export button by its text
  const exportButton = withinSection.getByText('Export Form Responses (CSV)');
  
  // Verify the target and rel attributes
  expect(exportButton).toHaveAttribute('target', '_blank');
  expect(exportButton).toHaveAttribute('rel', 'noopener');
});

test('export button has correct CSS classes and aria-label', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const clientForm = {
    id: '42',
    form: { name: 'Customer Onboarding' },
    status: 'validated'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: clientForm
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Find the export button by its text
  const exportButton = withinSection.getByText('Export Form Responses (CSV)');
  
  // Verify the CSS classes
  expect(exportButton).toHaveClass('inline-flex', 'items-center', 'rounded-md', 'px-4', 'py-2', 'text-sm', 'font-semibold', 'bg-background', 'border', 'shadow-xs');
  
  // Verify the aria-label
  expect(exportButton).toHaveAttribute('aria-label', 'Export form responses as CSV');
});

test('shows link form when client_form is null and forms are available', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const forms = [
    { id: '1', name: 'Form A' },
    { id: '2', name: 'Form B' }
  ];
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms,
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  // Should show the form dropdown
  const select = withinSection.getByRole('combobox');
  expect(select).toBeInTheDocument();
  expect(withinSection.getByText('Form A')).toBeInTheDocument();
  expect(withinSection.getByText('Form B')).toBeInTheDocument();
  expect(withinSection.getByText('Create subspace')).toBeInTheDocument();
});

test('shows "No forms available" message when no forms exist and client_form is null', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('No forms available yet. Create a form first.')).toBeInTheDocument();
});

test('shows client_form details when client_form exists', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const clientForm = {
    id: '42',
    form: { name: 'Customer Onboarding' },
    status: 'validated'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: clientForm
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('Has a subspace')).toBeInTheDocument();
  expect(withinSection.getByText('Customer Onboarding')).toBeInTheDocument();
  expect(withinSection.getByText('validated')).toBeInTheDocument();
});

test('shows "Client not found" message when client is null', () => {
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client: null,
      session_id: 'session-123',
      forms: [],
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('Client not found.')).toBeInTheDocument();
});

test('renders Edit and Delete buttons', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('Edit')).toBeInTheDocument();
  expect(withinSection.getByText('Delete')).toBeInTheDocument();
});

test('renders Export (CSV) button for client', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('Export (CSV)')).toBeInTheDocument();
});

test('renders Back to clients and Back to dashboard buttons', () => {
  const client = {
    id: '1',
    name: 'Acme Corp',
    company_name: 'Acme Inc.',
    status: 'active'
  };
  const { container } = render(ShowClient, {
    props: {
      user: { email: 'test@example.com' },
      client,
      session_id: 'session-123',
      forms: [],
      client_form: null
    }
  });
  const mainSection = container.querySelector('section');
  const withinSection = within(mainSection!);

  expect(withinSection.getByText('Back to clients')).toBeInTheDocument();
  expect(withinSection.getByText('Back to dashboard')).toBeInTheDocument();
});
