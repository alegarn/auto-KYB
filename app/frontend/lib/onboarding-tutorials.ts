import type {
  DashboardOnboarding,
  DashboardOnboardingStep,
  DashboardOnboardingStepKey,
  GuideKey,
  GuidePractice,
  OnboardingTutorialKey,
} from '@/types/dashboard-onboarding';

export const ONBOARDING_TUTORIAL_QUERY_PARAM = 'onboarding_tutorial';
export const ONBOARDING_TUTORIAL_LOCATION_CHANGE_EVENT = 'quick-kyb:onboarding-tutorial-location-change';

export type OnboardingTutorialActionKind = 'focus' | 'click' | 'scroll';

export type OnboardingTutorialStep = {
  title: string;
  body: string;
  target: string;
  action?: {
    kind: OnboardingTutorialActionKind;
    label: string;
  };
  missingTargetBody?: string;
};

export type OnboardingTutorial = {
  key: OnboardingTutorialKey;
  guideKey: GuideKey;
  title: string;
  summary: string;
  steps: OnboardingTutorialStep[];
};

const TUTORIALS: Record<OnboardingTutorialKey, OnboardingTutorial> = {
  form_builder_basics: {
    key: 'form_builder_basics',
    guideKey: 'form_builder',
    title: 'Tune the form structure',
    summary: 'Rename the form, inspect the field palette, and move around the builder without leaving the real page.',
    steps: [
      {
        title: 'Rename the form',
        body: 'Use a workflow-specific name so the client understands what they are filling out before you share access.',
        target: '#form-name',
        action: { kind: 'focus', label: 'Focus the name field' },
      },
      {
        title: 'Open the field palette',
        body: 'The palette is where you add new inputs like text, date, checkbox, select, and file uploads.',
        target: '[data-onboarding-tutorial="form-builder-palette"]',
        action: { kind: 'scroll', label: 'Jump to the palette' },
      },
      {
        title: 'Work inside the canvas',
        body: 'The canvas shows the live order of the fields. Reordering here changes what the client sees.',
        target: '[data-onboarding-tutorial="form-builder-canvas"]',
        action: { kind: 'scroll', label: 'Center the canvas' },
      },
      {
        title: 'Preview before you share',
        body: 'Switch to preview mode to sanity check the flow on the same screen before a client ever sees it.',
        target: '[data-onboarding-tutorial="form-preview-toggle"]',
        action: { kind: 'click', label: 'Switch to preview' },
      },
    ],
  },
  form_export_basics: {
    key: 'form_export_basics',
    guideKey: 'form_builder',
    title: 'Prepare export-friendly output',
    summary: 'Use the real mapping controls so the data shape is clean before you export or connect a CRM.',
    steps: [
      {
        title: 'Open field mapping',
        body: 'The mapping tab is where you normalize export keys and avoid collisions before the data leaves Quick KYB.',
        target: '[data-onboarding-tutorial="form-builder-mapping-tab"]',
        action: { kind: 'click', label: 'Open mapping' },
      },
      {
        title: 'Review output formats',
        body: 'When preview results are available, switch between JSON and CSV from this area to validate how exports will look.',
        target: '[data-onboarding-tutorial="form-output-format"]',
        action: { kind: 'scroll', label: 'Show output formats' },
        missingTargetBody: 'This control appears after you submit the preview once. If it is missing, switch to Preview, submit sample data, then continue.',
      },
    ],
  },
  client_profile_basics: {
    key: 'client_profile_basics',
    guideKey: 'client_workflow',
    title: 'Create a client profile',
    summary: 'Fill the real client form in-place so your onboarding moves from a template into a real workflow.',
    steps: [
      {
        title: 'Link the form first',
        body: 'Choose which workspace form this client should receive. This is what unlocks secure subspace access.',
        target: '#client-form',
        action: { kind: 'focus', label: 'Focus the form selector' },
      },
      {
        title: 'Add the company identity',
        body: 'Use the legal company name you want downstream exports and CRM mappings to rely on.',
        target: '#client-company',
        action: { kind: 'focus', label: 'Focus company name' },
      },
      {
        title: 'Capture a working email',
        body: 'This email becomes the most practical anchor for follow-up, exports, and CRM matching.',
        target: '#client-email',
        action: { kind: 'focus', label: 'Focus work email' },
      },
      {
        title: 'Save the client profile',
        body: 'Once the basics are filled in, create the client profile and continue the secure access flow from the client page.',
        target: '[data-onboarding-tutorial="client-submit"]',
        action: { kind: 'scroll', label: 'Show the save action' },
      },
    ],
  },
  client_exports_basics: {
    key: 'client_exports_basics',
    guideKey: 'client_workflow',
    title: 'Review and export client data',
    summary: 'Use the actual client export controls so you can inspect the inventory before sending data elsewhere.',
    steps: [
      {
        title: 'Find the export inventory',
        body: 'This section groups profile exports and validated response exports in one place.',
        target: '[data-onboarding-tutorial="client-exports"]',
        action: { kind: 'scroll', label: 'Jump to exports' },
      },
      {
        title: 'Try the JSON export',
        body: 'Open the JSON export to inspect the raw shape that internal tools or APIs can consume.',
        target: '[data-onboarding-tutorial="client-export-json"]',
        action: { kind: 'click', label: 'Open JSON export' },
      },
      {
        title: 'Compare with the CSV export',
        body: 'Use the CSV export when you need spreadsheet-friendly output for operations, finance, or manual review.',
        target: '[data-onboarding-tutorial="client-export-csv"]',
        action: { kind: 'click', label: 'Open CSV export' },
      },
    ],
  },
  crm_sync_basics: {
    key: 'crm_sync_basics',
    guideKey: 'crm_sync',
    title: 'Connect and tune CRM sync',
    summary: 'Practice on the real settings page so you know where connection and sync behavior actually live.',
    steps: [
      {
        title: 'Open the CRM integrations area',
        body: 'This card lists each provider and its current connection state.',
        target: '[data-onboarding-tutorial="crm-integrations"]',
        action: { kind: 'scroll', label: 'Jump to CRM integrations' },
      },
      {
        title: 'Use the connect action',
        body: 'From here you start or retry the OAuth connection flow for a provider.',
        target: '[data-onboarding-tutorial="crm-connect-button"]',
        action: { kind: 'click', label: 'Use the connection control' },
        missingTargetBody: 'A dedicated Connect button is not visible because the providers may already be connected. You can still use this card to test or disconnect them.',
      },
      {
        title: 'Decide how portal submissions sync',
        body: 'This toggle controls whether validated portal submissions push automatically or wait for a manual export.',
        target: '[data-onboarding-tutorial="crm-auto-sync-toggle"]',
        action: { kind: 'click', label: 'Toggle sync behavior' },
      },
    ],
  },
};

function relativeUrl(url: string): URL {
  return new URL(url, 'https://quick-kyb.local');
}

function isTutorialKey(value: string | null): value is OnboardingTutorialKey {
  return value !== null && value in TUTORIALS;
}

function findStep(onboarding: DashboardOnboarding, key: DashboardOnboardingStepKey): DashboardOnboardingStep | undefined {
  return onboarding.quick_steps.find((step) => step.key === key);
}

function concreteClientPageHref(href: string | null | undefined): string | null {
  if (!href) return null;

  const pathname = relativeUrl(href).pathname;
  return /^\/clients\/[^/]+$/.test(pathname) ? href : null;
}

export function withOnboardingTutorial(href: string, tutorialKey: OnboardingTutorialKey): string {
  const url = relativeUrl(href);
  url.searchParams.set(ONBOARDING_TUTORIAL_QUERY_PARAM, tutorialKey);
  return `${url.pathname}${url.search}${url.hash}`;
}

export function getOnboardingTutorialKey(url: string | URL | null | undefined): OnboardingTutorialKey | null {
  if (!url) return null;

  const parsed = typeof url === 'string' ? relativeUrl(url) : relativeUrl(url.toString());
  const key = parsed.searchParams.get(ONBOARDING_TUTORIAL_QUERY_PARAM);
  return isTutorialKey(key) ? key : null;
}

export function getOnboardingTutorial(tutorialKey: OnboardingTutorialKey): OnboardingTutorial {
  return TUTORIALS[tutorialKey];
}

export function clearOnboardingTutorialFromCurrentLocation() {
  if (typeof window === 'undefined') return;

  const url = new URL(window.location.href);
  url.searchParams.delete(ONBOARDING_TUTORIAL_QUERY_PARAM);
  window.history.replaceState(window.history.state, '', `${url.pathname}${url.search}${url.hash}`);
  window.dispatchEvent(
    new CustomEvent(ONBOARDING_TUTORIAL_LOCATION_CHANGE_EVENT, {
      detail: { href: `${url.pathname}${url.search}${url.hash}` },
    }),
  );
}

export function getGuidePracticeItems(guideKey: GuideKey, onboarding: DashboardOnboarding): GuidePractice[] {
  const formHref = findStep(onboarding, 'form')?.href ?? '/forms/new';
  const reviewHref = findStep(onboarding, 'review')?.href ?? null;
  const concreteReviewHref = concreteClientPageHref(reviewHref);

  switch (guideKey) {
    case 'form_builder':
      return [
        {
          tutorialKey: 'form_builder_basics',
          title: 'Tune the form structure',
          description: 'Practice directly on the live builder: rename the form, inspect the palette, and switch to preview.',
          ctaLabel: 'Start mini tutorial',
          href: withOnboardingTutorial(formHref, 'form_builder_basics'),
        },
        {
          tutorialKey: 'form_export_basics',
          title: 'Prepare export-friendly output',
          description: 'Open mapping and validate how your output will look before you share the form or export data.',
          ctaLabel: 'Practice mapping',
          href: withOnboardingTutorial(formHref, 'form_export_basics'),
        },
      ];
    case 'client_workflow':
      return [
        {
          tutorialKey: 'client_profile_basics',
          title: 'Create a client profile',
          description: 'Fill the real client form in-place and save a client profile without leaving the tutorial context.',
          ctaLabel: 'Open client tutorial',
          href: withOnboardingTutorial('/clients/new', 'client_profile_basics'),
        },
        {
          tutorialKey: 'client_exports_basics',
          title: 'Review and export client data',
          description: 'Use the real client export panel to compare JSON and CSV downloads on an actual client record.',
          ctaLabel: 'Practice exports',
          href: concreteReviewHref ? withOnboardingTutorial(concreteReviewHref, 'client_exports_basics') : null,
          unavailableReason: concreteReviewHref ? undefined : 'Create or open a client record first so the export panel exists on the page.',
        },
      ];
    case 'crm_sync':
      return [
        {
          tutorialKey: 'crm_sync_basics',
          title: 'Connect and tune CRM sync',
          description: 'Practice on the live settings page so you know where provider connections and auto-sync controls really live.',
          ctaLabel: 'Open CRM tutorial',
          href: withOnboardingTutorial('/settings', 'crm_sync_basics'),
        },
      ];
  }
}