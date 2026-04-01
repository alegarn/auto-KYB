export interface ClientFormData {
  name: string;
  email: string;
  companyName: string;
  companyId: string;
  phone: string;
  selectedCountry: string;
  street: string;
  city: string;
  postal: string;
}

/**
 * Checks if the company information is sufficient to show a creation notice or proceed with sync.
 * @param name - The name of the company.
 * @param id - The registration ID of the company.
 * @returns boolean indicating if the company info is completed.
 */
export function isCompanyInfoCompleted(name: string | null | undefined, id: string | null | undefined): boolean {
  if (!name || !id) return false;
  return name.trim().length > 2 && id.trim().length > 1;
}

/**
 * Maps CRM prefill data to form data structure.
 * @param prefillData - The raw prefill data from the CRM.
 * @returns A partial form data object.
 */
export function mapCrmPrefillToForm(prefillData: any): Partial<ClientFormData> {
  if (!prefillData) return {};

  return {
    name: prefillData.name || undefined,
    email: prefillData.email || undefined,
    companyName: prefillData.company_name || undefined,
    companyId: prefillData.company_id || undefined,
    phone: prefillData.phone || undefined,
    selectedCountry: prefillData.country || undefined,
    street: prefillData.address?.street || undefined,
    city: prefillData.address?.city || undefined,
    postal: prefillData.address?.postal_code || undefined,
  };
}
