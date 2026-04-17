import { countCrmValidationIssuesForProvider, groupCrmValidationIssues } from './validation';
import { requestCrmMappingValidation } from './live-validation';
import type { CrmMappingField, CrmMappingValidationIssue, CrmMappingValidationIssueGroups } from './types';

interface VerifyCrmMappingsParams {
  formId?: string | number | null;
  crmProperties: Record<string, unknown>;
  serializedFields: CrmMappingField[];
  validationUrl?: string | null;
  csrfToken: string;
  isOpen: () => boolean;
}

export class CrmLiveValidationWorkflow {
  issues = $state<CrmMappingValidationIssueGroups>({});
  error = $state<string | null>(null);
  validating = $state(false);

  #controller: AbortController | null = null;
  #sessionToken = 0;

  reset = () => {
    this.issues = {};
    this.error = null;
  };

  abort = () => {
    this.#controller?.abort();
    this.#controller = null;
    this.validating = false;
  };

  closeSession = () => {
    this.abort();
    this.reset();
    this.#sessionToken += 1;
  };

  getIssues = (provider: string, fieldKey: string): CrmMappingValidationIssue[] => {
    return this.issues[provider]?.[fieldKey] || [];
  };

  countForProvider = (provider: string): number => {
    return countCrmValidationIssuesForProvider(this.issues, provider);
  };

  verify = async ({
    formId,
    crmProperties,
    serializedFields,
    validationUrl,
    csrfToken,
    isOpen,
  }: VerifyCrmMappingsParams): Promise<boolean> => {
    if (!formId || Object.keys(crmProperties).length === 0 || !validationUrl) {
      this.reset();
      return true;
    }

    const sessionToken = this.#sessionToken;

    this.#controller?.abort();
    const controller = new AbortController();
    this.#controller = controller;

    this.validating = true;
    this.error = null;

    try {
      const { ok, payload } = await requestCrmMappingValidation(
        validationUrl,
        serializedFields,
        csrfToken,
        controller.signal,
      );

      if (
        controller.signal.aborted
        || !isOpen()
        || this.#controller !== controller
        || sessionToken !== this.#sessionToken
      ) {
        return false;
      }

      this.issues = groupCrmValidationIssues(Array.isArray(payload.issues) ? payload.issues : []);

      if (ok && payload.valid !== false) {
        this.error = null;
        return true;
      }

      this.error = typeof payload.error === 'string' ? payload.error : null;
      return false;
    } catch {
      if (
        controller.signal.aborted
        || !isOpen()
        || this.#controller !== controller
        || sessionToken !== this.#sessionToken
      ) {
        return false;
      }

      this.issues = {};
      this.error = 'Live CRM verification failed. Please try again.';
      return false;
    } finally {
      if (this.#controller === controller) {
        this.#controller = null;
        this.validating = false;
      }
    }
  };
}
