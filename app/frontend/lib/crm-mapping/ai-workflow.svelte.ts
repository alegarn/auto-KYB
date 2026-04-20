import { requestAiAutoMap, type AiSuggestion } from '../crm/ai-auto-map';

import {
  aiSuggestionMatchesCrmMapping,
  buildAiAutoMapRequest,
  buildAiLoadingFieldKeySets,
  DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE,
  getAiAutoMapErrorMessage,
  normalizeAiSuggestions,
} from './ai';
import { mergeAiSuggestionsDraft } from './draft';
import type {
  CrmExportKeyOverrides,
  CrmMappingIndexedField,
  CrmMappings,
} from './types';

export interface CrmAiAutoMapProgress {
  roundNumber: number;
  batchNumber: number;
  totalBatches: number;
  mappedCount: number;
  remainingCount: number;
}

interface RunCrmAiAutoMapParams {
  provider: string;
  formId?: string | number | null;
  isOpen: () => boolean;
  indexedFields: CrmMappingIndexedField[];
  fieldIdToStateKey: Record<string, string>;
  getDraft: () => { mappings: CrmMappings; exportKeyOverrides: CrmExportKeyOverrides };
  applyDraftUpdate: (next: { mappings: CrmMappings; exportKeyOverrides: CrmExportKeyOverrides }) => void;
  countRemainingFields: (provider: string, nextMappings?: CrmMappings) => number;
  onCompleted?: () => Promise<void> | void;
}

export class CrmAiAutoMapWorkflow {
  suggestions = $state<Record<string, Record<string, AiSuggestion>>>({});
  loading = $state<Record<string, boolean>>({});
  pendingFieldKeys = $state<Record<string, string[]>>({});
  errors = $state<Record<string, string | null>>({});
  progress = $state<Record<string, CrmAiAutoMapProgress | null>>({});
  reviewNoticeVisible = $state<Record<string, boolean>>({});

  loadingFieldKeys = $derived.by(() => buildAiLoadingFieldKeySets(this.pendingFieldKeys));
  hasActiveRun = $derived.by(() => Object.values(this.loading).some(Boolean));

  #controllers = new Map<string, AbortController>();

  reset = () => {
    for (const controller of this.#controllers.values()) {
      controller.abort();
    }

    this.#controllers.clear();
    this.suggestions = {};
    this.loading = {};
    this.pendingFieldKeys = {};
    this.errors = {};
    this.progress = {};
    this.reviewNoticeVisible = {};
  };

  getSuggestion = (provider: string, fieldKey: string): AiSuggestion | undefined => {
    return this.suggestions[provider]?.[fieldKey];
  };

  matchesSuggestion = (provider: string, fieldKey: string, mapping?: Parameters<typeof aiSuggestionMatchesCrmMapping>[0]) => {
    return aiSuggestionMatchesCrmMapping(mapping, this.getSuggestion(provider, fieldKey));
  };

  run = async ({
    provider,
    formId,
    isOpen,
    indexedFields,
    fieldIdToStateKey,
    getDraft,
    applyDraftUpdate,
    countRemainingFields,
    onCompleted,
  }: RunCrmAiAutoMapParams) => {
    if (!formId || this.hasActiveRun) return;

    const initialDraft = getDraft();
    const initialRequest = buildAiAutoMapRequest(
      indexedFields,
      initialDraft.mappings,
      provider,
      fieldIdToStateKey,
      { batchSize: DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE },
    );

    if (initialRequest.unmappedFields.length === 0) return;

    const maxRounds = Math.max(1, initialRequest.totalUnmappedCount);

    this.loading = { ...this.loading, [provider]: true };
    this.pendingFieldKeys = { ...this.pendingFieldKeys, [provider]: [] };
    this.errors = { ...this.errors, [provider]: null };
    this.progress = { ...this.progress, [provider]: null };
    this.reviewNoticeVisible = { ...this.reviewNoticeVisible, [provider]: false };
    this.#controllers.get(provider)?.abort();

    const controller = new AbortController();
    this.#controllers.set(provider, controller);

    try {
      let roundNumber = 0;
      let totalMappedThisRun = 0;
      let encounteredError = false;

      while (roundNumber < maxRounds) {
        if (!isOpen() || this.#controllers.get(provider) !== controller || controller.signal.aborted) return;

        const roundDraft = getDraft();
        const roundRequest = buildAiAutoMapRequest(
          indexedFields,
          roundDraft.mappings,
          provider,
          fieldIdToStateKey,
          { batchSize: DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE },
        );

        if (roundRequest.unmappedFields.length === 0) break;

        roundNumber += 1;
        let mappedThisRound = 0;
        const roundFieldIds = roundRequest.allUnmappedFieldIds;
        const totalBatches = Math.ceil(roundFieldIds.length / DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE);

        for (let batchIndex = 0; batchIndex < totalBatches; batchIndex += 1) {
          if (!isOpen() || this.#controllers.get(provider) !== controller || controller.signal.aborted) return;

          const batchFieldIds = roundFieldIds.slice(
            batchIndex * DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE,
            (batchIndex + 1) * DEFAULT_CRM_AI_AUTO_MAP_BATCH_SIZE,
          );

          const batchDraft = getDraft();
          const request = buildAiAutoMapRequest(
            indexedFields,
            batchDraft.mappings,
            provider,
            fieldIdToStateKey,
            { fieldIds: batchFieldIds },
          );

          if (request.unmappedFields.length === 0) continue;

          this.pendingFieldKeys = {
            ...this.pendingFieldKeys,
            [provider]: request.pendingFieldKeys,
          };
          this.progress = {
            ...this.progress,
            [provider]: {
              roundNumber,
              batchNumber: batchIndex + 1,
              totalBatches,
              mappedCount: totalMappedThisRun,
              remainingCount: request.totalUnmappedCount,
            },
          };

          const result = await requestAiAutoMap(
            formId,
            provider,
            request.unmappedFields,
            request.alreadyMapped,
            request.draftFields,
            controller.signal,
          );

          if (!isOpen() || this.#controllers.get(provider) !== controller || controller.signal.aborted) return;

          const latestDraft = getDraft();
          const merged = mergeAiSuggestionsDraft(
            latestDraft.mappings,
            latestDraft.exportKeyOverrides,
            result.suggestions,
            provider,
            fieldIdToStateKey,
          );
          const remainingAfterBatch = countRemainingFields(provider, merged.mappings);
          const mappedThisBatch = Math.max(0, request.totalUnmappedCount - remainingAfterBatch);

          mappedThisRound += mappedThisBatch;
          totalMappedThisRun += mappedThisBatch;

          applyDraftUpdate({
            mappings: merged.mappings,
            exportKeyOverrides: merged.exportKeyOverrides,
          });
          this.suggestions = {
            ...this.suggestions,
            [provider]: {
              ...(this.suggestions[provider] || {}),
              ...normalizeAiSuggestions(result.suggestions, fieldIdToStateKey),
            },
          };
          this.progress = {
            ...this.progress,
            [provider]: {
              roundNumber,
              batchNumber: batchIndex + 1,
              totalBatches,
              mappedCount: totalMappedThisRun,
              remainingCount: remainingAfterBatch,
            },
          };

          if (result.error) {
            this.errors = { ...this.errors, [provider]: getAiAutoMapErrorMessage(result.error) };
            encounteredError = true;
            break;
          }
        }

        if (encounteredError) break;

        const remainingAfterRound = countRemainingFields(provider);
        if (remainingAfterRound === 0 || mappedThisRound === 0) break;
      }

      if (!encounteredError) {
        this.reviewNoticeVisible = { ...this.reviewNoticeVisible, [provider]: true };
        await onCompleted?.();
      }
    } catch (error: unknown) {
      if (controller.signal.aborted) return;

      const message = error instanceof Error ? error.message : 'ai_auto_map_failed';
      this.errors = { ...this.errors, [provider]: getAiAutoMapErrorMessage(message) };
    } finally {
      if (this.#controllers.get(provider) === controller) {
        this.#controllers.delete(provider);
        this.loading = { ...this.loading, [provider]: false };
        this.pendingFieldKeys = { ...this.pendingFieldKeys, [provider]: [] };
        this.progress = { ...this.progress, [provider]: null };
      }
    }
  };
}