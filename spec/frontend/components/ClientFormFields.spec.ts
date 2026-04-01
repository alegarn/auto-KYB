import { render, screen, cleanup } from '@testing-library/svelte';
import { describe, it, expect, afterEach, vi } from 'vitest';
import ClientFormFields from '../../../app/frontend/components/ClientFormFields.svelte';
import { mount } from 'svelte';

describe('ClientFormFields.svelte', () => {
  afterEach(() => {
    cleanup();
  });

  const mockCountries = [
    { name: 'United States', code: 'US', flag: '🇺🇸' },
    { name: 'France', code: 'FR', flag: '🇫🇷' }
  ];

  const defaultProps = {
    formData: {
      name: '',
      email: '',
      phone: '',
      companyName: '',
      companyId: '',
      selectedCountry: '',
      street: '',
      city: '',
      postal: ''
    },
    errors: {},
    countries: mockCountries,
    countriesLoading: false,
    onFetchCountries: async () => {}
  } as const;

  it('renders all required form sections and labels', () => {
    render(ClientFormFields, { props: defaultProps });

    expect(screen.getByText(/Client Personal Details/i)).toBeDefined();
    expect(screen.getByText(/Company Information/i)).toBeDefined();
    expect(screen.getByLabelText(/Full Name/i)).toBeDefined();
    expect(screen.getByLabelText(/Personal\/Work Email/i)).toBeDefined();
    expect(screen.getByLabelText(/Phone Number/i)).toBeDefined();
    expect(screen.getByLabelText(/Registered Company Name/i)).toBeDefined();
    expect(screen.getByLabelText(/Company Registration ID/i)).toBeDefined();
    expect(screen.getByLabelText(/Country/i)).toBeDefined();
    expect(screen.getByLabelText(/Street/i)).toBeDefined();
    expect(screen.getByLabelText(/City/i)).toBeDefined();
    expect(screen.getByLabelText(/Postal Code/i)).toBeDefined();
  });

  it('populates the country dropdown with provided countries', () => {
    render(ClientFormFields, { props: defaultProps });
    
    const select = screen.getByLabelText(/Country/i) as HTMLSelectElement;
    expect(select.options.length).toBe(mockCountries.length + 1); // +1 for "Select a country"
    expect(screen.getByText(/🇺🇸 United States/i)).toBeDefined();
    expect(screen.getByText(/🇫🇷 France/i)).toBeDefined();
  });

  it('shows loading state for countries', () => {
    render(ClientFormFields, { 
      props: { ...defaultProps, countriesLoading: true } 
    });
    
    expect(screen.getByText(/Loading countries.../i)).toBeDefined();
  });

  it('displays validation errors when present', () => {
    const errors = {
      name: ['can\'t be blank'],
      email: ['is invalid'],
      company_name: ['is too short'],
      company_id: ['has already been taken']
    };

    render(ClientFormFields, { 
      props: { ...defaultProps, errors } 
    });

    expect(screen.getByText("can't be blank")).toBeDefined();
    expect(screen.getByText("is invalid")).toBeDefined();
    expect(screen.getByText("is too short")).toBeDefined();
    expect(screen.getByText("has already been taken")).toBeDefined();
  });

  it('applies error styling classes to invalid fields', () => {
    const errors = {
      name: ['error']
    };

    render(ClientFormFields, { 
      props: { ...defaultProps, errors } 
    });

    const nameInput = screen.getByLabelText(/Full Name/i);
    expect(nameInput.className).toContain('border-rose-600');
  });
});
