import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { fetchCountriesData } from '/lib/countries';

describe('fetchCountriesData', () => {
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    globalThis.fetch = vi.fn();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    vi.resetAllMocks();
  });

  it('fetches /countries?v=3 and returns normalized data with flags and sorted by name', async () => {
    const mockData = [
      { name: 'Norway', code: 'NO' },
      { name: 'United States', code: 'US' },
      { name: 'Albania', code: 'AL' }
    ];

    (globalThis.fetch as any).mockResolvedValue({ ok: true, json: async () => mockData });

    const result = await fetchCountriesData();
    expect(globalThis.fetch).toHaveBeenCalledWith('/countries?v=3');
    expect(Array.isArray(result)).toBe(true);
    // flags should be present
    const norway = result.find((c: any) => c.code === 'NO');
    expect(norway).toBeTruthy();
    expect(norway?.flag).toBe('🇳🇴');
    // sorted by name: Albania, Norway, United States
    expect(result.map((r: any) => r.name)).toEqual(['Albania', 'Norway', 'United States']);
  });

  it('throws when fetch fails', async () => {
    (globalThis.fetch as any).mockResolvedValue({ ok: false, status: 500, statusText: 'Server Error' });
    await expect(fetchCountriesData()).rejects.toThrow('HTTP 500');
  });
});
