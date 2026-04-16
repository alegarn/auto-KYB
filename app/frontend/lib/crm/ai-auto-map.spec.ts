import { beforeEach, describe, expect, it, vi } from 'vitest';

import { form_ai_field_suggestions_path } from '@/routes';

import { requestAiAutoMap } from './ai-auto-map';

describe('requestAiAutoMap', () => {
  const mockFetch = vi.fn();

  beforeEach(() => {
    global.fetch = mockFetch as typeof fetch;
    mockFetch.mockReset();
    document.head.innerHTML = '<meta name="csrf-token" content="csrf-token" />';
  });

  it('parses a successful AI auto-map response', async () => {
    const payload = {
      suggestions: {
        'field-1': {
          object_type: 'contact',
          property_name: 'email',
          confidence: 'high',
          reason: 'Direct semantic match',
        },
      },
      unmapped_count: 0,
      error: null,
    };

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => payload,
    });

    await expect(
      requestAiAutoMap(
        '42',
        'hubspot',
        [ { id: 'field-1', label: 'Work Email', field_type: 'email' } ],
        [ 'contact::firstname' ],
      ),
    ).resolves.toEqual(payload);

    expect(mockFetch).toHaveBeenCalledWith(form_ai_field_suggestions_path('42'), {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': 'csrf-token',
      },
      body: JSON.stringify({
        provider: 'hubspot',
        unmapped_fields: [ { id: 'field-1', label: 'Work Email', field_type: 'email' } ],
        already_mapped: [ 'contact::firstname' ],
      }),
    });
  });

  it('throws the backend reason for a forbidden response', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: async () => ({ error: 'plan_insufficient' }),
    });

    await expect(requestAiAutoMap('42', 'hubspot', [], [])).rejects.toThrow('plan_insufficient');
  });

  it('throws rate_limited when the request is throttled', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      json: async () => ({ error: 'rate_limited' }),
    });

    await expect(requestAiAutoMap('42', 'hubspot', [], [])).rejects.toThrow('rate_limited');
  });

  it('rethrows network errors', async () => {
    mockFetch.mockRejectedValueOnce(new Error('Network down'));

    await expect(requestAiAutoMap('42', 'hubspot', [], [])).rejects.toThrow('Network down');
  });
});