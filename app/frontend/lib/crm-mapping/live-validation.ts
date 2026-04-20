import type { CrmMappingField, CrmMappingValidationIssue } from './types';

export interface CrmMappingValidationResponsePayload {
  valid?: boolean;
  issues?: CrmMappingValidationIssue[];
  error?: string | null;
}

export interface CrmMappingValidationResponse {
  ok: boolean;
  payload: CrmMappingValidationResponsePayload;
}

export async function requestCrmMappingValidation(
  url: string,
  fields: CrmMappingField[],
  csrfToken: string,
  signal: AbortSignal,
): Promise<CrmMappingValidationResponse> {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
    },
    signal,
    body: JSON.stringify({ fields }),
  });

  const payload = await response.json().catch(() => ({}));

  return {
    ok: response.ok,
    payload,
  };
}
