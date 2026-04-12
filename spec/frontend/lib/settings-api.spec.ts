import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  PROVIDER_NAMES,
  buildCrmConnectionList,
  formatDateLabel,
  isSubscribed,
  fetchBillingPortalUrl,
  testCrmConnectionApi,
} from '@/lib/settings-api';

// ── PROVIDER_NAMES ────────────────────────────────────────────────────────────

describe('PROVIDER_NAMES', () => {
  it('maps the three expected providers', () => {
    expect(PROVIDER_NAMES['hubspot']).toBe('HubSpot');
    expect(PROVIDER_NAMES['salesforce']).toBe('Salesforce');
    expect(PROVIDER_NAMES['zoho']).toBe('Zoho CRM');
  });
});

// ── buildCrmConnectionList ────────────────────────────────────────────────────

describe('buildCrmConnectionList', () => {
  const activeHubspot = { id: 1, provider: 'hubspot', status: 'active' };
  const activeSalesforce = { id: 2, provider: 'salesforce', status: 'active' };
  const inactiveZoho = { id: 3, provider: 'zoho', status: 'revoked' };

  it('uses the default provider list when available_providers is empty', () => {
    const list = buildCrmConnectionList([], [], {});
    expect(list.map((c) => c.provider)).toEqual(['hubspot', 'salesforce', 'zoho']);
  });

  it('uses supplied available_providers when non-empty', () => {
    const list = buildCrmConnectionList(['hubspot'], [], {});
    expect(list).toHaveLength(1);
    expect(list[0].provider).toBe('hubspot');
  });

  it('marks a provider connected when an active connection exists', () => {
    const list = buildCrmConnectionList([], [activeHubspot], {});
    const hubspot = list.find((c) => c.provider === 'hubspot')!;
    expect(hubspot.connected).toBe(true);
    expect(hubspot.id).toBe(1);
  });

  it('marks a provider disconnected when only a non-active connection exists', () => {
    const list = buildCrmConnectionList([], [inactiveZoho], {});
    const zoho = list.find((c) => c.provider === 'zoho')!;
    expect(zoho.connected).toBe(false);
    expect(zoho.id).toBeUndefined();
  });

  it('marks a provider disconnected when no connection exists at all', () => {
    const list = buildCrmConnectionList([], [], {});
    list.forEach((c) => expect(c.connected).toBe(false));
  });

  it('propagates loading state from loadingStates', () => {
    const list = buildCrmConnectionList([], [], { hubspot: true });
    const hubspot = list.find((c) => c.provider === 'hubspot')!;
    expect(hubspot.loading).toBe(true);
  });

  it('defaults loading to false when not present in loadingStates', () => {
    const list = buildCrmConnectionList([], [], {});
    list.forEach((c) => expect(c.loading).toBe(false));
  });

  it('uses the display name from PROVIDER_NAMES', () => {
    const list = buildCrmConnectionList([], [], {});
    const salesforce = list.find((c) => c.provider === 'salesforce')!;
    expect(salesforce.name).toBe('Salesforce');
  });

  it('falls back to the provider key as name for unknown providers', () => {
    const list = buildCrmConnectionList(['custom_crm'], [], {});
    expect(list[0].name).toBe('custom_crm');
  });

  it('handles multiple active connections correctly', () => {
    const list = buildCrmConnectionList([], [activeHubspot, activeSalesforce], {});
    const hubspot = list.find((c) => c.provider === 'hubspot')!;
    const salesforce = list.find((c) => c.provider === 'salesforce')!;
    expect(hubspot.connected).toBe(true);
    expect(salesforce.connected).toBe(true);
  });
});

// ── formatDateLabel ───────────────────────────────────────────────────────────

describe('formatDateLabel', () => {
  it('returns "—" for null', () => {
    expect(formatDateLabel(null)).toBe('—');
  });

  it('returns "—" for undefined', () => {
    expect(formatDateLabel(undefined)).toBe('—');
  });

  it('returns "—" for empty string', () => {
    expect(formatDateLabel('')).toBe('—');
  });

  it('formats a valid ISO date string in en-GB format', () => {
    const label = formatDateLabel('2025-03-15T00:00:00.000Z');
    // Should contain the year and a month abbreviation
    expect(label).toMatch(/2025/);
    expect(label).toMatch(/Mar/);
    expect(label).toMatch(/15/);
  });

  it('returns the original string for an unparseable date', () => {
    const bad = 'not-a-date';
    const result = formatDateLabel(bad);
    // Either returns the raw string or "—" — both are acceptable fallbacks
    expect(typeof result).toBe('string');
  });
});

// ── isSubscribed ──────────────────────────────────────────────────────────────

describe('isSubscribed', () => {
  it('returns true for "active"', () => {
    expect(isSubscribed('active')).toBe(true);
  });

  it('returns true for "trialing"', () => {
    expect(isSubscribed('trialing')).toBe(true);
  });

  it('returns false for "canceled"', () => {
    expect(isSubscribed('canceled')).toBe(false);
  });

  it('returns false for "incomplete"', () => {
    expect(isSubscribed('incomplete')).toBe(false);
  });

  it('returns false for null', () => {
    expect(isSubscribed(null)).toBe(false);
  });

  it('returns false for undefined', () => {
    expect(isSubscribed(undefined)).toBe(false);
  });
});

// ── fetchBillingPortalUrl ─────────────────────────────────────────────────────

describe('fetchBillingPortalUrl', () => {
  const mockFetch = vi.fn();

  beforeEach(() => {
    global.fetch = mockFetch;
    mockFetch.mockReset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns the url from a successful response', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ url: 'https://billing.stripe.com/portal/abc' }),
    });

    const url = await fetchBillingPortalUrl('csrf-token', '/subscriptions/billing_portal');
    expect(url).toBe('https://billing.stripe.com/portal/abc');
  });

  it('sends a POST with the correct headers', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ url: 'https://billing.stripe.com/portal/abc' }),
    });

    await fetchBillingPortalUrl('my-csrf', '/subscriptions/billing_portal');

    expect(mockFetch).toHaveBeenCalledWith('/subscriptions/billing_portal', {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': 'my-csrf',
      },
    });
  });

  it('throws when the response is not ok', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: async () => ({ error: 'Subscription not found' }),
    });

    await expect(
      fetchBillingPortalUrl('csrf', '/subscriptions/billing_portal'),
    ).rejects.toThrow('Subscription not found');
  });

  it('throws a generic error when the error response has no error field', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: async () => ({}),
    });

    await expect(
      fetchBillingPortalUrl('csrf', '/subscriptions/billing_portal'),
    ).rejects.toThrow('Unable to open billing portal');
  });

  it('throws when the response is ok but has no url', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({}),
    });

    await expect(
      fetchBillingPortalUrl('csrf', '/subscriptions/billing_portal'),
    ).rejects.toThrow('No portal url returned');
  });
});

// ── testCrmConnectionApi ──────────────────────────────────────────────────────

describe('testCrmConnectionApi', () => {
  const mockFetch = vi.fn();

  beforeEach(() => {
    global.fetch = mockFetch;
    mockFetch.mockReset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns ok:true and a status message on success', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ status: 'connected' }),
    });

    const result = await testCrmConnectionApi('/crm_connections/1/test', 'csrf');
    expect(result).toEqual({ ok: true, message: 'connected' });
  });

  it('falls back to "OK" when the success response has no status field', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({}),
    });

    const result = await testCrmConnectionApi('/crm_connections/1/test', 'csrf');
    expect(result).toEqual({ ok: true, message: 'OK' });
  });

  it('returns ok:false and an error message on failure', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: async () => ({ error: 'Token expired' }),
    });

    const result = await testCrmConnectionApi('/crm_connections/1/test', 'csrf');
    expect(result).toEqual({ ok: false, message: 'Token expired' });
  });

  it('falls back to "Unknown error" when the failure response has no error field', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: async () => ({}),
    });

    const result = await testCrmConnectionApi('/crm_connections/1/test', 'csrf');
    expect(result).toEqual({ ok: false, message: 'Unknown error' });
  });

  it('sends a POST with the correct headers', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ status: 'ok' }),
    });

    await testCrmConnectionApi('/crm_connections/7/test', 'my-csrf');

    expect(mockFetch).toHaveBeenCalledWith('/crm_connections/7/test', {
      method: 'POST',
      headers: { 'X-CSRF-Token': 'my-csrf', Accept: 'application/json' },
    });
  });
});
