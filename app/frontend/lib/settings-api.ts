export const PROVIDER_NAMES: Record<string, string> = {
  hubspot: 'HubSpot',
  salesforce: 'Salesforce',
  zoho: 'Zoho CRM',
};

export interface CrmConnectionEntry {
  id: number | undefined;
  provider: string;
  name: string;
  connected: boolean;
  status: string | undefined;
  loading: boolean;
}

export function buildCrmConnectionList(
  availableProviders: string[],
  connections: Array<{ provider: string; status: string; id: number }>,
  loadingStates: Record<string, boolean>,
): CrmConnectionEntry[] {
  const providers =
    availableProviders.length > 0 ? availableProviders : ['hubspot', 'salesforce', 'zoho'];
  return providers.map((provider) => {
    const conn = connections?.find((c) => c.provider === provider && c.status === 'active');
    return {
      id: conn?.id,
      provider,
      name: PROVIDER_NAMES[provider] || provider,
      connected: !!conn,
      status: conn?.status,
      loading: !!loadingStates[provider],
    };
  });
}

export function formatDateLabel(dateString: string | null | undefined): string {
  if (!dateString) return '—';
  try {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-GB', { year: 'numeric', month: 'short', day: 'numeric' });
  } catch {
    return dateString;
  }
}

export function isSubscribed(status: string | null | undefined): boolean {
  return status === 'active' || status === 'trialing';
}

/** Calls the billing portal endpoint and resolves with the redirect URL. */
export async function fetchBillingPortalUrl(csrfToken: string, path: string): Promise<string> {
  const res = await fetch(path, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
    },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as { error?: string }).error || 'Unable to open billing portal');
  }
  const body = await res.json();
  if (!body.url) throw new Error('No portal url returned');
  return body.url as string;
}

export interface CrmTestResult {
  ok: boolean;
  message: string;
}

/** POSTs to the CRM connection test endpoint and returns a normalised result. */
export async function testCrmConnectionApi(
  testPath: string,
  csrfToken: string,
): Promise<CrmTestResult> {
  const response = await fetch(testPath, {
    method: 'POST',
    headers: { 'X-CSRF-Token': csrfToken, Accept: 'application/json' },
  });
  const result = await response.json();
  return response.ok
    ? { ok: true, message: result.status || 'OK' }
    : { ok: false, message: result.error || 'Unknown error' };
}
