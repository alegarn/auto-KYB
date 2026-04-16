import { form_ai_field_suggestions_path } from '@/routes';

export interface AiSuggestion {
  object_type: 'contact' | 'company';
  property_name: string | null;
  confidence: 'high' | 'medium';
  reason?: string;
  suggest_custom?: boolean;
  suggested_custom_name?: string;
}

export interface AiAutoMapResult {
  suggestions: Record<string, AiSuggestion>;
  unmapped_count: number;
  error: string | null;
}

export interface AiAutoMapFieldInput {
  id: string | number;
  label: string;
  field_type: string;
}

export async function requestAiAutoMap(
  formId: string | number,
  provider: string,
  unmappedFields: AiAutoMapFieldInput[],
  alreadyMapped: string[],
  signal?: AbortSignal,
): Promise<AiAutoMapResult> {
  const csrfToken = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement | null)?.content || '';

  const response = await fetch(form_ai_field_suggestions_path(formId), {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
    },
    body: JSON.stringify({
      provider,
      unmapped_fields: unmappedFields,
      already_mapped: alreadyMapped,
    }),
    signal,
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error((payload as { error?: string }).error || 'ai_auto_map_failed');
  }

  return payload as AiAutoMapResult;
}