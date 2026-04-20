import { render, screen } from '@testing-library/svelte';
import { describe, expect, it } from 'vitest';

import CrmMappingModal from './CrmMappingModal.svelte';

describe('CrmMappingModal', () => {
  const baseProps = {
    open: true,
    form: {},
    fields: [],
    onsave: () => {},
    ontestcrm: () => {},
  };

  it('shows the loader while connected CRM properties are still deferred', () => {
    render(CrmMappingModal, {
      props: {
        ...baseProps,
        crmProperties: undefined,
        activeCrmProviders: ['hubspot'],
        loadingProperties: true,
      },
    });

    expect(screen.getByText('Fetching CRM properties...')).toBeInTheDocument();
    expect(screen.queryByText(/No active CRM connection found/i)).not.toBeInTheDocument();
  });

  it('shows the no-connection state when no CRM provider is active', () => {
    render(CrmMappingModal, {
      props: {
        ...baseProps,
        crmProperties: {},
        activeCrmProviders: [],
        loadingProperties: false,
      },
    });

    expect(screen.getByText(/No active CRM connection found/i)).toBeInTheDocument();
    expect(screen.queryByText('Fetching CRM properties...')).not.toBeInTheDocument();
  });

  it('shows an unavailable alert when a connected CRM returns no properties', () => {
    render(CrmMappingModal, {
      props: {
        ...baseProps,
        crmProperties: {
          hubspot: {
            contact: [],
            company: [],
          },
        },
        activeCrmProviders: ['hubspot'],
        loadingProperties: false,
      },
    });

    expect(screen.getByText(/could not load your connected CRM properties/i)).toBeInTheDocument();
    expect(screen.queryByText('Fetching CRM properties...')).not.toBeInTheDocument();
    expect(screen.queryByText(/No active CRM connection found/i)).not.toBeInTheDocument();
  });
});