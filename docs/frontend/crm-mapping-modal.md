# CRM Mapping Modal

## Responsibilities

- `app/frontend/components/customs/CrmMappingModal.svelte`
  - owns the modal session
  - owns the editable CRM mapping draft
  - coordinates save and test actions
- `app/frontend/lib/crm-mapping/*.ts`
  - owns pure CRM mapping domain logic
  - keeps serialization, mapping transforms, validation grouping, and property filtering independent from Svelte components
- `app/frontend/lib/crm-mapping/*.svelte.ts`
  - owns stateful workflows that need runes, async coordination, or DOM lifecycle hooks
  - current workflows:
    - live CRM validation
    - AI auto-map orchestration
    - mapping table hover and keyboard scrolling
- `app/frontend/components/customs/crm-mapping/*.svelte`
  - owns provider-specific presentation
  - keeps the modal focused on orchestration instead of nested UI details

## Layering

1. Parent forms pages pass `open`, `fields`, CRM properties, and callbacks into the modal.
2. The modal hydrates a draft from field metadata and delegates UI rendering to provider-focused child components.
3. Provider child components emit mapping change actions back to the modal.
4. The modal delegates async work to workflow objects and pure data work to the CRM mapping domain modules.
5. Save and test actions always serialize the latest draft and run live CRM validation before calling parent callbacks.

## Refactor Guardrails

- Keep the draft source of truth in the modal unless the parent contract changes.
- Keep pure transforms in plain TypeScript modules.
- Keep async workflow state out of presentational components.
- Preserve existing `data-testid` hooks on the provider status and mapping table surfaces because the modal specs depend on them.